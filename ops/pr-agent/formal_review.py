"""Publish commit-bound GitHub reviews after a verified, complete agent run."""
import asyncio
from contextlib import asynccontextmanager
from contextvars import ContextVar
from copy import deepcopy
import fcntl
from functools import wraps
import hashlib
from pathlib import Path
import tempfile

MARKER = "<!-- pr-agent:formal-review:v1 -->"
REPOSITORY = "iqbalmaulana03/pujangga-pos"
_reconciliation = ContextVar("formal_review_reconciliation", default=None)


@asynccontextmanager
async def review_lock(provider):
    # Both Gunicorn workers share this directory. Serialize review and approval
    # so an older run cannot approve after a newer run has found a problem.
    identity = f"{provider.repo}:{provider.pr_num}"
    name = hashlib.sha256(identity.encode()).hexdigest()
    with (Path(tempfile.gettempdir()) / f"pr-agent-review-{name}.lock").open("a") as lock:
        # Nonblocking attempts keep cancellation from leaving a background
        # thread that acquires the lock after its file descriptor is closed.
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                await asyncio.sleep(0.1)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def review_outcome(reviewer, sha, failed):
    """Fail closed: silence, partial coverage, and untracked findings never pass."""
    if failed or not getattr(reviewer, "prediction", None):
        return "incomplete"
    if getattr(reviewer, "_review_state_blocked", True):
        return "incomplete"
    result = getattr(reviewer, "_review_state_result", None) or getattr(reviewer, "_formal_state_result", None)
    state = getattr(result, "state", None)
    if not isinstance(state, dict):
        return "incomplete"
    run = state.get("last_run", {})
    if (run.get("complete") is not True or run.get("kind") != "full"
            or run.get("head_sha") != sha or run.get("excluded_files") != []
            or getattr(reviewer.incremental, "is_incremental", True)
            or getattr(reviewer, "review_failed_chunk_count", 1) != 0
            or getattr(reviewer, "remaining_files_list", [None])
            or getattr(reviewer, "partial_files_list", [None])):
        return "incomplete"
    findings = state.get("findings")
    data = getattr(reviewer, "_formal_review_data", None) or getattr(reviewer, "prediction_data", None)
    review = data.get("review") if isinstance(data, dict) else None
    issues = review.get("key_issues_to_review") if isinstance(review, dict) else None
    if not isinstance(findings, list) or not isinstance(issues, list):
        return "incomplete"
    if any(not isinstance(f, dict) or f.get("state") not in {"ACTIVE", "RESOLVED"} for f in findings):
        return "incomplete"
    if issues or any(f["state"] == "ACTIVE" for f in findings):
        return "findings"
    if str(review.get("security_concerns", "")).strip().casefold() != "no":
        return "findings"
    return "clean"


def dismiss_approvals(provider):
    """Only revoke approvals authored by this App with our explicit marker."""
    for review in provider.pr.get_reviews():
        if (review.state == "APPROVED" and MARKER in (review.body or "")
                and provider.is_comment_authored_by_pr_agent(review)):
            review.dismiss("PR-Agent sedang mereview ulang; persetujuan sebelumnya dicabut.")


def publish_outcome(provider, sha, outcome):
    # Use a fresh API object: provider.pr is the snapshot used for the diff.
    fresh = provider.repo_obj.get_pull(provider.pr_num)
    if fresh.state != "open" or fresh.draft or fresh.head.sha != sha:
        return False
    if outcome == "clean":
        event = "APPROVE"
        message = ("✅ Review agen selesai: **disetujui**. Tidak ditemukan temuan aktif "
                   "pada review lengkap commit ini.\n\n"
                   "Persetujuan ini menandakan review kode oleh agen telah selesai. "
                   "Pastikan CI, konflik, dan syarat branch protection juga terpenuhi sebelum merge.")
    elif outcome == "findings":
        event = "COMMENT"
        message = ("⚠️ Review agen selesai dengan temuan yang perlu diperiksa. "
                   "**Belum disetujui**; lihat komentar PR Reviewer Guide di Conversation.")
    else:
        event = "COMMENT"
        message = ("❌ Review agen gagal atau belum lengkap. **Belum disetujui**. "
                   "Periksa hasil review atau jalankan `/review` untuk mencoba kembali.")
    body = f"{MARKER}\n\n{message}\n\nCommit yang direview: `{sha}`."
    submitted = fresh.create_review(commit=provider.repo_obj.get_commit(sha), body=body, event=event)
    expected = "APPROVED" if event == "APPROVE" else "COMMENTED"
    if submitted.state != expected or submitted.commit_id != sha:
        raise RuntimeError("Formal review publication could not be verified")
    # A push can land between the last read and create_review. Revoke the
    # approval immediately if it no longer refers to the current open PR.
    current = provider.repo_obj.get_pull(provider.pr_num)
    if event == "APPROVE" and (current.head.sha != sha or current.draft or current.state != "open"):
        submitted.dismiss("Commit atau status PR berubah saat persetujuan dipublikasikan.")
        return False
    return True


def install():
    from pr_agent.algo.run_details import command_failed
    from pr_agent.config_loader import get_settings
    from pr_agent.log import get_logger
    from pr_agent.tools.pr_reviewer import PRReviewer
    from pr_agent.tools import pr_reviewer

    prepare = PRReviewer._prepare_review_finding_state
    if getattr(prepare, "_formal_review", False) is not True:
        @wraps(prepare)
        def capture_data(self, data):
            # The single-chunk path can leave prediction_data unset; use the
            # actual validated data supplied to the upstream state builder.
            self._formal_review_data = deepcopy(data)
            return prepare(self, data)
        capture_data._formal_review = True
        PRReviewer._prepare_review_finding_state = capture_data

    # Upstream deliberately omits the persisted state marker on the first
    # clean review. Capture its real reconciliation result without fabricating
    # success from an absent comment or modifying upstream persistence behavior.
    reconcile = pr_reviewer.reconcile_review_findings
    if getattr(reconcile, "_formal_review", False) is not True:
        @wraps(reconcile)
        def capture(*args, **kwargs):
            result = reconcile(*args, **kwargs)
            _reconciliation.set(result)
            return result
        capture._formal_review = True
        pr_reviewer.reconcile_review_findings = capture

    original = PRReviewer.run
    if getattr(original, "_formal_review", False) is True:
        return

    @wraps(original)
    async def run(self):
        settings = get_settings()
        provider = self.git_provider
        if (not settings.config.publish_output
                or settings.pr_reviewer.get("publish_formal_review", False) is not True
                or getattr(provider, "repo", "") != REPOSITORY
                or settings.get("github.deployment_type", "") != "app"):
            return await original(self)
        async with review_lock(provider):
            sha = provider.get_pr_head_sha()
            fresh = await asyncio.to_thread(provider.repo_obj.get_pull, provider.pr_num)
            if fresh.state != "open" or fresh.draft or not sha or fresh.head.sha != sha:
                return
            # If revocation fails, do not risk leaving an old approval while
            # issuing another result. API errors remain private and fail closed.
            await asyncio.to_thread(dismiss_approvals, provider)
            token = _reconciliation.set(None)
            try:
                result = await original(self)
                self._formal_state_result = _reconciliation.get()
            except Exception:
                await asyncio.to_thread(publish_outcome, provider, sha, "incomplete")
                raise
            finally:
                _reconciliation.reset(token)
            outcome = review_outcome(self, sha, command_failed())
            try:
                await asyncio.to_thread(publish_outcome, provider, sha, outcome)
            except Exception as error:
                get_logger().error("Formal review publication failed: " + type(error).__name__)
                raise
            return result

    run._formal_review = True
    PRReviewer.run = run
