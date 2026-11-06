"""Exercise the actual PR-Agent handler without GitHub writes or application data."""
import asyncio
import json
import sys

from codex_lb import install

install()

from pr_agent.algo.ai_handlers.litellm_ai_handler import LiteLLMAIHandler
from pr_agent.config_loader import get_settings
from pr_agent.log import get_logger


async def main():
    get_logger().remove()
    settings = get_settings()
    try:
        text, finish = await LiteLLMAIHandler().chat_completion(
            model=settings.config.model,
            system="Reply only OK.",
            user="Deployment connectivity check. Reply OK.",
            temperature=0,
        )
        passed = text.strip() == "OK"
        print(json.dumps({"model": settings.config.model, "reply_ok": passed, "finish_reason": finish}))
        return 0 if passed else 1
    except Exception as error:
        # This diagnostic contains only a synthetic prompt. Redact the key and
        # retain one bounded error line, never a traceback or full response.
        detail = str(error).replace(settings.openai.key, "[REDACTED]").splitlines()[0][:600]
        print(json.dumps({"reply_ok": False, "error_type": type(error).__name__, "detail": detail}))
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
