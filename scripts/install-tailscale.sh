#!/bin/sh
set -eu

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")" && pwd
)

. "$SCRIPT_DIR/lib.sh"

host=${1:-$RM_WIFI_HOST}

echo "installing tailscale ${RM_TAILSCALE_VERSION} on ${host}"

rm_ssh "$host" sh -s -- "$RM_TAILSCALE_VERSION" "$RM_TAILSCALE_DIR" "$RM_TAILSCALE_SOCKET" <<'REMOTE'
set -eu

VERSION=$1
BASE=$2
SOCKET=$3
ARCH=arm64
PKG="tailscale_${VERSION}_${ARCH}.tgz"
URL="https://pkgs.tailscale.com/stable/${PKG}"
SUM_FILE="${PKG}.sha256"
SUM_URL="${URL}.sha256"

mkdir -p "$BASE/download" "$BASE/bin" "$BASE/state"
cd "$BASE/download"

if ! { [ -x "$BASE/bin/tailscale" ] && [ -x "$BASE/bin/tailscaled" ] \
  && "$BASE/bin/tailscale" version 2>/dev/null | sed -n '1s/ .*//p' | grep -Fxq "$VERSION"; }; then
  rm -rf "tailscale_${VERSION}_${ARCH}" "$PKG" "$SUM_FILE"
  wget -q "$URL" -O "$PKG"
  wget -q "$SUM_URL" -O "$SUM_FILE"
  IFS= read -r expected_sum < "$SUM_FILE"
  printf '%s  %s\n' "$expected_sum" "$PKG" | sha256sum -c -
  tar xzf "$PKG"
  cp "tailscale_${VERSION}_${ARCH}/tailscale" "tailscale_${VERSION}_${ARCH}/tailscaled" "$BASE/bin/"
  chmod 755 "$BASE/bin/tailscale" "$BASE/bin/tailscaled"
fi

mount -o remount,rw /

cat > /etc/systemd/system/tailscaled-remarkable.service <<EOF
[Unit]
Description=Tailscale on reMarkable
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
ExecStart=$BASE/bin/tailscaled --state=$BASE/state/tailscaled.state --socket=$SOCKET --tun=userspace-networking
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now tailscaled-remarkable.service
systemctl --no-pager --full status tailscaled-remarkable.service | sed -n '1,12p'
REMOTE

echo "next: ./scripts/tailscale-up.sh ${host}"
