"""Approval gates and GitHub publication tested without model or GitHub calls."""
from types import SimpleNamespace as NS
import unittest
from unittest.mock import AsyncMock, Mock, patch

import formal_review as formal

SHA = "a" * 40


def reviewer():
    return NS(prediction="valid response", _review_state_blocked=False,
              incremental=NS(is_incremental=False), review_failed_chunk_count=0,
              remaining_files_list=[], partial_files_list=[],
              prediction_data={"review": {"key_issues_to_review": [], "security_concerns": "No"}},
              _review_state_result=NS(state={"findings": [], "last_run": {
                  "complete": True, "kind": "full", "head_sha": SHA, "excluded_files": []}}))


def provider():
    pr = Mock(state="open", draft=False, head=NS(sha=SHA))
    pr.get_reviews.return_value = []
    p = Mock(repo=formal.REPOSITORY, pr_num=1, pr=pr)
    p.repo_obj.get_pull.return_value = pr
    p.get_pr_head_sha.return_value = SHA
    pr.create_review.side_effect = lambda **kw: Mock(
        state="APPROVED" if kw["event"] == "APPROVE" else "COMMENTED", commit_id=SHA)
    return p


class OutcomeTests(unittest.TestCase):
    def test_complete_clean_review_can_approve(self):
        self.assertEqual(formal.review_outcome(reviewer(), SHA, False), "clean")

    def test_first_clean_review_uses_captured_reconciliation(self):
        r = reviewer()
        r._formal_state_result = r._review_state_result
        r._review_state_result = None
        self.assertEqual(formal.review_outcome(r, SHA, False), "clean")

    def test_single_chunk_review_uses_actual_prepared_data(self):
        r = reviewer()
        r._formal_review_data = r.prediction_data
        r.prediction_data = None
        self.assertEqual(formal.review_outcome(r, SHA, False), "clean")

    def test_failure_partial_stale_or_missing_evidence_never_approves(self):
        cases = [lambda r: setattr(r, "prediction", None),
                 lambda r: setattr(r, "_review_state_blocked", True),
                 lambda r: setattr(r, "_review_state_result", None),
                 lambda r: setattr(r, "review_failed_chunk_count", 1),
                 lambda r: setattr(r, "remaining_files_list", ["large.py"]),
                 lambda r: setattr(r, "partial_files_list", ["large.py"]),
                 lambda r: setattr(r.incremental, "is_incremental", True),
                 lambda r: r._review_state_result.state["last_run"].update(complete=False),
                 lambda r: r._review_state_result.state["last_run"].update(head_sha="old"),
                 lambda r: r.prediction_data["review"].pop("key_issues_to_review")]
        for change in cases:
            with self.subTest(change=change):
                r = reviewer()
                change(r)
                self.assertEqual(formal.review_outcome(r, SHA, False), "incomplete")
        self.assertEqual(formal.review_outcome(reviewer(), SHA, True), "incomplete")

    def test_active_or_untracked_issues_and_security_prevent_approval(self):
        for field, value in [("key_issues_to_review", [{"issue_content": "untracked"}]),
                             ("security_concerns", "Possible leak")]:
            r = reviewer()
            r.prediction_data["review"][field] = value
            self.assertEqual(formal.review_outcome(r, SHA, False), "findings")
        r = reviewer()
        r._review_state_result.state["findings"] = [{"state": "ACTIVE"}]
        self.assertEqual(formal.review_outcome(r, SHA, False), "findings")
        r._review_state_result.state["findings"] = [{"state": "RESOLVED"}]
        self.assertEqual(formal.review_outcome(r, SHA, False), "clean")


class PublicationTests(unittest.TestCase):
    def test_approval_is_bound_to_exact_reviewed_commit(self):
        p = provider()
        self.assertTrue(formal.publish_outcome(p, SHA, "clean"))
        kw = p.pr.create_review.call_args.kwargs
        self.assertEqual(kw["event"], "APPROVE")
        self.assertIs(kw["commit"], p.repo_obj.get_commit.return_value)
        p.repo_obj.get_commit.assert_called_once_with(SHA)
        self.assertIn(SHA, kw["body"])
        self.assertIn("CI", kw["body"])

    def test_findings_and_failure_publish_comments_not_approvals(self):
        for outcome in ["findings", "incomplete"]:
            p = provider()
            formal.publish_outcome(p, SHA, outcome)
            self.assertEqual(p.pr.create_review.call_args.kwargs["event"], "COMMENT")

    def test_changed_closed_or_draft_pr_is_never_approved(self):
        for changes in [{"draft": True}, {"state": "closed"}, {"head": NS(sha="new")}]:
            p = provider()
            for key, value in changes.items():
                setattr(p.pr, key, value)
            self.assertFalse(formal.publish_outcome(p, SHA, "clean"))
            p.pr.create_review.assert_not_called()

    def test_push_during_publication_revokes_approval(self):
        p = provider()
        p.repo_obj.get_pull.side_effect = [p.pr, NS(state="open", draft=False, head=NS(sha="new"))]
        submitted = Mock(state="APPROVED", commit_id=SHA)
        p.pr.create_review.side_effect = None
        p.pr.create_review.return_value = submitted
        self.assertFalse(formal.publish_outcome(p, SHA, "clean"))
        submitted.dismiss.assert_called_once()

    def test_revocation_only_affects_our_marked_approvals(self):
        p = provider()
        own = Mock(state="APPROVED", body=formal.MARKER)
        human = Mock(state="APPROVED", body=formal.MARKER)
        other = Mock(state="APPROVED", body="another bot")
        p.pr.get_reviews.return_value = [own, human, other]
        p.is_comment_authored_by_pr_agent.side_effect = lambda r: r is own
        formal.dismiss_approvals(p)
        own.dismiss.assert_called_once()
        human.dismiss.assert_not_called()
        other.dismiss.assert_not_called()


class LifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def test_first_review_captures_the_actual_upstream_result(self):
        from pr_agent.tools import pr_reviewer
        from pr_agent.tools.pr_reviewer import PRReviewer
        settings = NS(config=NS(publish_output=True),
                      pr_reviewer={"publish_formal_review": True}, get=lambda *a: "app")
        async def first_run(r):
            pr_reviewer.reconcile_review_findings(None, [], allow_resolution=True,
                excluded_files=[], head_sha=SHA, run_id="test")
        with patch.object(PRReviewer, "run", first_run), patch("pr_agent.config_loader.get_settings", return_value=settings), patch("pr_agent.algo.run_details.command_failed", return_value=False):
            formal.install()
            r = reviewer()
            r._review_state_result = None
            r.git_provider = provider()
            await PRReviewer.run(r)
            self.assertEqual(r.git_provider.pr.create_review.call_args.kwargs["event"], "APPROVE")

    async def test_dry_run_has_no_formal_publication(self):
        from pr_agent.tools.pr_reviewer import PRReviewer
        original = AsyncMock(return_value="done")
        settings = NS(config=NS(publish_output=False), pr_reviewer={}, get=lambda *a: "app")
        with patch.object(PRReviewer, "run", original), patch("pr_agent.config_loader.get_settings", return_value=settings):
            formal.install()
            r = reviewer()
            r.git_provider = provider()
            self.assertEqual(await PRReviewer.run(r), "done")
            r.git_provider.repo_obj.get_pull.assert_not_called()

    async def test_success_and_swallowed_failure_are_distinguished(self):
        from pr_agent.tools.pr_reviewer import PRReviewer
        settings = NS(config=NS(publish_output=True),
                      pr_reviewer={"publish_formal_review": True}, get=lambda *a: "app")
        for failed, expected in [(False, "APPROVE"), (True, "COMMENT")]:
            original = AsyncMock(return_value="done")
            with patch.object(PRReviewer, "run", original), patch("pr_agent.config_loader.get_settings", return_value=settings), patch("pr_agent.algo.run_details.command_failed", return_value=failed):
                formal.install()
                r = reviewer()
                r.git_provider = provider()
                await PRReviewer.run(r)
                self.assertEqual(r.git_provider.pr.create_review.call_args.kwargs["event"], expected)


if __name__ == "__main__":
    unittest.main()
