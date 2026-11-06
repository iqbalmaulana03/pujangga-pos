"""Focused checks for the deployment's transport and write restrictions."""
import unittest
from string import Formatter
from unittest.mock import AsyncMock

import codex_lb
from pr_agent.algo.ai_handlers.litellm_ai_handler import LiteLLMAIHandler
from pr_agent.config_loader import get_settings


class TransportTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.endpoint = "https://model.example.com/responses"
        self.old_endpoint = get_settings().get("deployment.allowed_api_base", "")
        get_settings().set("deployment.allowed_api_base", self.endpoint)
        self.original = LiteLLMAIHandler._acompletion
        self.transport = AsyncMock(return_value="result")
        LiteLLMAIHandler._acompletion = self.transport
        codex_lb.install()
        self.handler = object.__new__(LiteLLMAIHandler)

    async def asyncTearDown(self):
        LiteLLMAIHandler._acompletion = self.original
        get_settings().set("deployment.allowed_api_base", self.old_endpoint)

    async def test_instructions_and_no_storage_reach_transport(self):
        messages = [{"role": "system", "content": "Review carefully"}, {"role": "user", "content": "diff"}]
        result = await self.handler._acompletion(api_base=self.endpoint, messages=messages)
        self.assertEqual(result, "result")
        kwargs = self.transport.call_args.kwargs
        self.assertEqual(kwargs["extra_body"], {"store": False, "instructions": "Review carefully"})
        self.assertEqual(kwargs["messages"], [messages[1]])
        self.assertEqual(len(messages), 2)

    async def test_other_endpoints_cannot_receive_credentials(self):
        with self.assertRaises(ValueError):
            await self.handler._acompletion(api_base="https://example.invalid", messages=[])
        self.transport.assert_not_awaited()

    async def test_missing_private_allowlist_prevents_startup(self):
        get_settings().set("deployment.allowed_api_base", "")
        with self.assertRaises(ValueError):
            codex_lb.install()


class PolicyTests(unittest.IsolatedAsyncioTestCase):
    async def test_only_review_for_target_repository_is_dispatched(self):
        import bootstrap
        original = bootstrap.original_dispatch
        dispatch = AsyncMock(return_value={"ok": True})
        bootstrap.original_dispatch = dispatch
        try:
            body = {"repository": {"full_name": "iqbalmaulana03/pujangga-pos"},
                    "sender": {"type": "User"}, "comment": {"body": "/review"}}
            await bootstrap.review_only(body, "issue_comment", "created")
            self.assertEqual(dispatch.await_count, 1)
            for command in ("/improve", "/review --config.model=other", "/describe", "hello"):
                body["comment"]["body"] = command
                await bootstrap.review_only(body, "issue_comment", "created")
            body["comment"]["body"] = "/review"
            body["sender"]["type"] = "Bot"
            await bootstrap.review_only(body, "issue_comment", "created")
            body["repository"]["full_name"] = "other/repo"
            await bootstrap.review_only(body, "pull_request", "opened")
            self.assertEqual(dispatch.await_count, 1)
        finally:
            bootstrap.original_dispatch = original


class LocaleTests(unittest.TestCase):
    def test_indonesian_catalog_covers_all_keys_and_preserves_placeholders(self):
        from pr_agent.algo.i18n import _load_catalog, locale_chain
        english = _load_catalog("en")
        indonesian = _load_catalog("id")
        self.assertEqual(set(english), set(indonesian))
        self.assertEqual(locale_chain("id-ID"), ["id", "en"])
        for key, text in english.items():
            fields = lambda value: {name for _, name, _, _ in Formatter().parse(value) if name}
            self.assertEqual(fields(text), fields(indonesian[key]), key)


if __name__ == "__main__":
    unittest.main()
