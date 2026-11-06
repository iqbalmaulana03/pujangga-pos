"""Host-owned compatibility shim for the verified codex-lb Responses endpoint.

PR-Agent's extra_body configuration intentionally disallows store/instructions.
Set them at the transport boundary, without changing upstream or global LiteLLM.
"""


def install():
    from pr_agent.algo.ai_handlers.litellm_ai_handler import LiteLLMAIHandler
    from pr_agent.config_loader import get_settings

    endpoint = str(get_settings().get("deployment.allowed_api_base", "")).rstrip("/")
    if not endpoint.startswith("https://"):
        raise ValueError("A private HTTPS endpoint allowlist is required")

    original = LiteLLMAIHandler._acompletion
    if getattr(original, "_codex_lb", False) is True:
        return

    async def completion(self, *args, **kwargs):
        if str(kwargs.get("api_base", "")).rstrip("/") != endpoint:
            raise ValueError("This deployment only permits its configured codex-lb endpoint")
        messages = kwargs.get("messages", [])
        instructions = []
        inputs = []
        for message in messages:
            if message.get("role") in ("system", "developer"):
                content = message.get("content", "")
                if not isinstance(content, str):
                    raise ValueError("Expected text instructions")
                instructions.append(content)
            else:
                inputs.append(message)
        body = dict(kwargs.get("extra_body") or {})
        body["store"] = False
        body["instructions"] = "\n\n".join(instructions) or "Follow the user's review instructions."
        kwargs["extra_body"] = body
        kwargs["messages"] = inputs
        return await original(self, *args, **kwargs)

    completion._codex_lb = True
    LiteLLMAIHandler._acompletion = completion
