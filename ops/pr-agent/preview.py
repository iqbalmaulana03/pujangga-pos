"""Review PR #58 privately. The one-off GitHub token is never published."""
import json
from pathlib import Path
import sys
from urllib.request import Request, urlopen

from codex_lb import install

install()

from pr_agent.config_loader import get_settings
from pr_agent.cli import run
from pr_agent.log import get_logger


def main():
    get_logger().remove()
    token = Path("/deployment/github-token").read_text().strip()
    request = Request("https://api.github.com/repos/iqbalmaulana03/pujangga-pos/pulls/58", headers={
        "Authorization": "Bearer " + token, "User-Agent": "pujangga-pr-agent-validation"})
    with urlopen(request, timeout=20) as response:
        pr = json.load(response)
    expected = "91f59821ce4536f4eb35c82072695db35a7a309e"
    if pr["head"]["sha"] != expected or pr["state"] != "open":
        raise RuntimeError("PR head/state changed; reassess before reviewing")
    settings = get_settings()
    settings.set("GITHUB.DEPLOYMENT_TYPE", "user")
    settings.set("GITHUB.USER_TOKEN", token)
    settings.set("CONFIG.PUBLISH_OUTPUT", False)
    settings.set("CONFIG.PUBLISH_OUTPUT_PROGRESS", False)
    settings.set("CONFIG.PROPAGATE_TOOL_ERRORS", True)
    output = "/app/pr-agent-outputs/review58.json"
    sys.argv = ["pr-agent", "--pr_url", pr["html_url"], "--json-output", output, "review"]
    code = run() or 0
    print(json.dumps({"head": expected, "published": False, "exit_code": code, "output_exists": Path(output).is_file()}))
    return code


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({"published": False, "error_type": type(error).__name__}))
        raise SystemExit(1)
