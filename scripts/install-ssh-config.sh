#!/bin/sh
set -eu

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")" && pwd
)

. "$SCRIPT_DIR/lib.sh"

need_python

host=${1:-$RM_WIFI_HOST}

echo "reading tailscale dns name from ${host}"

status_json=$(
  rm_ssh "$host" \
    "'$RM_TAILSCALE_DIR'/bin/tailscale --socket='$RM_TAILSCALE_SOCKET' status --json"
)

dns_name=$(
  STATUS_JSON=$status_json run_python - <<'PY'
import json
import os

print(json.loads(os.environ["STATUS_JSON"])["Self"]["DNSName"].rstrip("."))
PY
)

if [ -z "$dns_name" ]; then
  echo "could not detect tailscale dns name" >&2
  exit 1
fi

echo "writing ~/.ssh/config host: ${RM_SSH_ALIAS} -> ${dns_name}"

run_python - "$dns_name" "$RM_SSH_ALIAS" "$RM_SSH_USER" "$RM_TAILSCALE_SSH_PORT" "$RM_TAILSCALE_HOSTKEY_ALIAS" <<'PY'
from pathlib import Path
import re
import sys

dns_name, alias, user, port, hostkey_alias = sys.argv[1:]
config_path = Path.home() / ".ssh" / "config"
config_path.parent.mkdir(parents=True, exist_ok=True)

block = (
    f"Host {alias}\n"
    f"    HostName {dns_name}\n"
    f"    User {user}\n"
    f"    HostKeyAlias {hostkey_alias}\n"
    f"    ProxyCommand tailscale nc %h {port}\n"
    f"    StrictHostKeyChecking accept-new\n"
)

text = config_path.read_text() if config_path.exists() else ""
pattern = re.compile(rf"(?ms)^Host[ \t]+{re.escape(alias)}\n(?:[ \t].*\n)*")

if pattern.search(text):
    text = pattern.sub(block, text, count=1)
else:
    if text and not text.endswith("\n"):
        text += "\n"
    if text:
        text += "\n"
    text += block

config_path.write_text(text)
PY

echo "done. test with: ssh ${RM_SSH_ALIAS}"
