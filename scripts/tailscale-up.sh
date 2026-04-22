#!/bin/sh
set -eu

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")" && pwd
)

. "$SCRIPT_DIR/lib.sh"

host=${1:-$RM_WIFI_HOST}
log_file="$RM_TAILSCALE_DIR/tailscale-up.log"
tmp_output=$(mktemp)
trap 'rm -f "$tmp_output"' EXIT HUP INT TERM

echo "starting tailscale auth flow on ${host}"

rm_ssh "$host" sh -s -- "$log_file" "$RM_TAILSCALE_DIR" "$RM_TAILSCALE_SOCKET" >"$tmp_output" <<'REMOTE'
set -eu

LOG_FILE=$1
BASE=$2
SOCKET=$3

rm -f "$LOG_FILE"
nohup "$BASE/bin/tailscale" --socket="$SOCKET" up > "$LOG_FILE" 2>&1 &

i=0
last_output=

while [ "$i" -lt 20 ]; do
  last_output=$(sed -n '1,20p' "$LOG_FILE" 2>/dev/null || true)

  case "$last_output" in
    *https://login.tailscale.com/*)
      printf '%s\n' "$last_output"
      exit 0
      ;;
  esac

  sleep 1
  i=$((i + 1))
done

printf '%s\n' "$last_output"
REMOTE

output=$(cat "$tmp_output")

printf '%s\n' "$output"

case "$output" in
  *https://login.tailscale.com/*)
    echo "approve url above, then run: ./scripts/install-tailscale-ssh-bridge.sh ${host}"
    ;;
  *)
    echo "if auth url did not print yet, rerun this script"
    ;;
esac
