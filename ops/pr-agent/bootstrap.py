"""ASGI entrypoint: pinned upstream plus deployment-specific transport/policy."""
from codex_lb import install

install()

from formal_review import install as install_formal_review

install_formal_review()

from pr_agent.servers import github_app

original_dispatch = github_app._dispatch_request


async def review_only(body, event, action):
    if body.get("repository", {}).get("full_name") != "iqbalmaulana03/pujangga-pos":
        return {}
    if event == "issue_comment":
        if body.get("sender", {}).get("type") == "Bot":
            return {}
        if body.get("comment", {}).get("body", "").strip() != "/review":
            return {}
    elif event != "pull_request":
        return {}
    return await original_dispatch(body, event, action)


github_app._dispatch_request = review_only
app = github_app.app
