#!/bin/sh
set -eu

ROOT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")/.." && pwd
)

ENV_FILE=${ENV_FILE:-"$ROOT_DIR/.env"}

if [ ! -f "$ENV_FILE" ]; then
  echo "missing env file: $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

: "${RM_USB_HOST:=10.11.99.1}"
: "${RM_WIFI_HOST:=192.168.5.44}"
: "${RM_SSH_USER:=root}"
: "${RM_SSH_ALIAS:=rem}"
: "${RM_TAILSCALE_VERSION:=1.96.4}"
: "${RM_TAILSCALE_SSH_PORT:=2222}"
: "${RM_TAILSCALE_DIR:=/home/root/tailscale}"
: "${RM_TAILSCALE_SOCKET:=/run/tailscale/tailscaled.sock}"
: "${RM_TAILSCALE_HOSTKEY_ALIAS:=remarkable-paper-pro}"
: "${RM_CONNECT_TIMEOUT:=10}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need_python() {
  if command -v uv >/dev/null 2>&1; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  echo "missing command: uv or python3" >&2
  exit 1
}

need_sshpass() {
  need_cmd sshpass
  [ -n "${SSH_PWD-}" ] || {
    echo "missing env: SSH_PWD" >&2
    exit 1
  }
  export SSHPASS=$SSH_PWD
}

rm_ssh() {
  host=$1
  shift

  need_sshpass

  sshpass -e ssh \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout="$RM_CONNECT_TIMEOUT" \
    "${RM_SSH_USER}@${host}" "$@"
}

run_python() {
  if command -v uv >/dev/null 2>&1; then
    uv run -- python "$@"
    return
  fi

  python3 "$@"
}
