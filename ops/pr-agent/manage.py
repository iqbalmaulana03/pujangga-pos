"""Deployment helper. Run as the deployment owner; never prints credentials."""
import argparse
import hashlib
import hmac
import html
import json
import os
from pathlib import Path
import secrets
import shlex
import subprocess
import tomllib
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parent
PRIVATE = ROOT / "private"
APP = PRIVATE / "app.json"
SOURCE_REVISION = "251eddf09e168f3abc15acfeed5062368540cdbf"
REPOSITORY = "iqbalmaulana03/pujangga-pos"


def deployment():
    """Host-specific values belong in an untracked private file."""
    values = tomllib.loads((PRIVATE / "deployment.toml").read_text())
    webhook = urlparse(values["webhook_url"])
    if webhook.scheme != "https" or not webhook.hostname or webhook.username or webhook.password:
        raise ValueError("Expected a public HTTPS webhook URL without credentials")
    if webhook.path != "/api/v1/github_webhooks" or webhook.query or webhook.fragment:
        raise ValueError("Unexpected webhook endpoint")
    return values


def private_write(path, text, mode=0o600):
    """Replace atomically; temporary files are private from creation."""
    PRIVATE.mkdir(mode=0o750, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.chmod(mode)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def configure():
    revision = subprocess.check_output(["git", "-C", str(ROOT / "source"), "rev-parse", "HEAD"], text=True).strip()
    if revision != SOURCE_REVISION:
        raise RuntimeError("Upstream revision differs from the tested deployment")
    host = deployment()
    config = tomllib.loads(Path(host["provider_config"]).expanduser().read_text())
    provider = config["model_providers"][config["model_provider"]]
    if config["model_provider"] != "codex-lb" or provider.get("wire_api") != "responses":
        raise RuntimeError("Expected the verified codex-lb Responses provider")
    endpoint = urlparse(provider["base_url"])
    if endpoint.scheme != "https" or not endpoint.hostname or endpoint.username or endpoint.password or endpoint.query or endpoint.fragment:
        raise ValueError("Expected a credential-free HTTPS provider endpoint")
    values = {}
    credentials = Path(host["credential_file"]).expanduser()
    if credentials.stat().st_uid != os.getuid() or credentials.stat().st_mode & 0o077:
        raise RuntimeError("Credential file must be owned by this user and private")
    for line in credentials.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            name, raw = line.split("=", 1)
            parts = shlex.split(raw)
            values[name.strip()] = parts[0] if parts else ""
    key = values.get(provider["env_key"], "")
    if not key:
        raise RuntimeError("Provider key is empty")
    PRIVATE.mkdir(mode=0o750, exist_ok=True)
    PRIVATE.chmod(0o750)
    if APP.exists():
        app = json.loads(APP.read_text())
    else:
        app = {"webhook_secret": secrets.token_hex(32)}
        # Retain the same secret on repeated initialization before App registration.
        settings = PRIVATE / ".secrets.toml"
        if settings.exists():
            app["webhook_secret"] = tomllib.loads(settings.read_text())["github"]["webhook_secret"]
    text = (ROOT / "config.toml").read_text()
    # Upstream requires both provider and endpoint matching to force streaming.
    # Keep the actual hostname in generated private settings only.
    text = text.replace("[litellm]", "[litellm]\nforce_streaming_api_base_substrings = " + json.dumps([endpoint.hostname]), 1)
    text += "\n[openai]\napi_base = " + json.dumps(provider["base_url"]) + "\nkey = " + json.dumps(key)
    text += '\n\n[github]\ndeployment_type = "app"\nwebhook_secret = ' + json.dumps(app["webhook_secret"])
    if "id" in app:
        text += "\napp_id = " + str(int(app["id"])) + "\nprivate_key = " + json.dumps(app["pem"])
    text += "\n"
    text += "\n[deployment]\nallowed_api_base = " + json.dumps(provider["base_url"].rstrip("/")) + "\n"
    tomllib.loads(text)
    private_write(PRIVATE / ".secrets.toml", text, 0o640)
    print("Konfigurasi privat diperbarui; nilai rahasia tidak ditampilkan.")


def compose(*args):
    subprocess.run(["docker", "compose", "-f", str(ROOT / "compose.yaml"), *args], cwd=ROOT, check=True)


def verify():
    settings = tomllib.loads((PRIVATE / ".secrets.toml").read_text())
    base = "http://127.0.0.1:8095"
    with urlopen(base + "/", timeout=10) as response:
        assert json.load(response) == {"status": "ok"}
    payload = b'{"zen":"deployment-check"}'
    for signed, expected in [(False, 403), (True, 200)]:
        headers = {"Content-Type": "application/json", "X-GitHub-Event": "ping"}
        if signed:
            digest = hmac.new(settings["github"]["webhook_secret"].encode(), payload, hashlib.sha256).hexdigest()
            headers["X-Hub-Signature-256"] = "sha256=" + digest
        try:
            with urlopen(Request(base + "/api/v1/github_webhooks", data=payload, headers=headers), timeout=15) as response:
                status = response.status
        except HTTPError as error:
            status = error.code
        print(json.dumps({"signed": signed, "status": status, "expected": expected}))
        if status != expected:
            raise RuntimeError("Webhook verification failed")


def register():
    if APP.exists():
        raise RuntimeError("App already registered; refusing to overwrite its private key")
    host = deployment()
    state = secrets.token_urlsafe(32)
    manifest = {
        "name": host["app_name"],
        "url": "https://github.com/" + REPOSITORY,
        "description": "Review PR Pujangga POS menggunakan PR-Agent dan codex-lb.",
        "hook_attributes": {"url": host["webhook_url"], "active": True},
        "redirect_url": "http://localhost:8096/callback",
        "public": False,
        "default_permissions": {"contents": "read", "metadata": "read", "pull_requests": "write", "issues": "write"},
        "default_events": ["pull_request", "issue_comment"],
    }

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # Callback URLs contain a one-time credential.

        def respond(self, code, content):
            self.send_response(code)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Referrer-Policy", "no-referrer")
            self.end_headers()
            self.wfile.write(content.encode())

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/":
                form = html.escape(json.dumps(manifest), quote=True)
                self.respond(200, '<!doctype html><meta charset="utf-8"><h1>Daftarkan reviewer Pujangga POS</h1>'
                             '<p>GitHub App hanya dipasang pada iqbalmaulana03/pujangga-pos. '
                             'Pada halaman instalasi, pilih Only select repositories dan pujangga-pos.</p>'
                             '<form method="post" action="https://github.com/settings/apps/new?state=' + state + '">'
                             f'<input type="hidden" name="manifest" value="{form}">'
                             '<button>Daftarkan GitHub App</button></form>')
                return
            query = parse_qs(parsed.query)
            if parsed.path != "/callback" or not secrets.compare_digest(query.get("state", [""])[0], state):
                self.respond(403, "Permintaan tidak valid.")
                return
            code = query.get("code", [""])[0]
            if not code or not code.isalnum() or APP.exists():
                self.respond(400, "Kode tidak valid atau App sudah terdaftar.")
                return
            try:
                request = Request("https://api.github.com/app-manifests/" + code + "/conversions", data=b"", headers={
                    "Accept": "application/vnd.github+json", "User-Agent": "pujangga-pr-agent-setup"})
                with urlopen(request, timeout=30) as response:
                    data = json.load(response)
                app = {name: data[name] for name in ("id", "slug", "pem", "webhook_secret")}
                private_write(APP, json.dumps(app))
                configure()
                compose("up", "-d", "--force-recreate")
                installation = "https://github.com/apps/" + app["slug"] + "/installations/new"
                self.respond(200, '<h1>App tersimpan aman di server</h1><p>Langkah berikutnya: '
                             'instal hanya pada pujangga-pos.</p><a href="' + html.escape(installation) + '">Install App</a>')
                print("GitHub App terdaftar; lanjutkan instalasi hanya pada " + REPOSITORY, flush=True)
            except Exception as error:
                print("Registrasi gagal: " + type(error).__name__, flush=True)
                self.respond(500, "Registrasi belum selesai. Lihat jenis error di terminal; rahasia tidak ditampilkan.")

    print("Buka http://127.0.0.1:8096 melalui SSH forwarding. Ctrl+C setelah selesai.", flush=True)
    HTTPServer(("127.0.0.1", 8096), Handler).serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["configure", "verify", "register"])
    args = parser.parse_args()
    try:
        {"configure": configure, "verify": verify, "register": register}[args.command]()
    except KeyboardInterrupt:
        pass
    except Exception as error:
        print("Gagal: " + type(error).__name__)
        raise SystemExit(1)
