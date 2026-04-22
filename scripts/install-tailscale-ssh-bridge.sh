#!/bin/sh
set -eu

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")" && pwd
)

. "$SCRIPT_DIR/lib.sh"

host=${1:-$RM_WIFI_HOST}

echo "installing tailscale ssh bridge on ${host}"

rm_ssh "$host" sh -s -- "$RM_TAILSCALE_DIR" "$RM_TAILSCALE_SOCKET" "$RM_TAILSCALE_SSH_PORT" <<'REMOTE'
set -eu

BASE=$1
SOCKET=$2
PORT=$3

mount -o remount,rw /

cat > "$BASE/update-serve-ssh.sh" <<EOF
#!/bin/sh
set -eu

PATH=/usr/sbin:/usr/bin:/sbin:/bin
TS=$BASE/bin/tailscale
SOCKET=$SOCKET
PORT=$PORT
DEV=wlan0

ip4=\$(
  ip -4 -o addr show dev "\$DEV" 2>/dev/null \
    | awk 'NR==1 {print \$4}' \
    | cut -d/ -f1
)

if [ -z "\${ip4:-}" ]; then
  ip4=\$(
    ifconfig "\$DEV" 2>/dev/null \
      | awk '/inet addr:/ {sub("addr:", "", \$2); print \$2; exit}'
  )
fi

if [ -z "\${ip4:-}" ]; then
  echo "no IPv4 on \$DEV" >&2
  exit 0
fi

if "\$TS" --socket="\$SOCKET" serve status 2>/dev/null | grep -Fq "|--> tcp://\$ip4:22"; then
  exit 0
fi

"\$TS" --socket="\$SOCKET" set --ssh >/dev/null 2>&1 || true
"\$TS" --socket="\$SOCKET" serve reset >/dev/null 2>&1 || true
"\$TS" --socket="\$SOCKET" serve --bg --yes --tcp "\$PORT" -- "tcp://\$ip4:22" >/dev/null
EOF

chmod 755 "$BASE/update-serve-ssh.sh"

cat > /etc/systemd/system/tailscale-serve-ssh.service <<EOF
[Unit]
Description=Refresh Tailscale SSH forward for reMarkable
After=network-online.target tailscaled-remarkable.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$BASE/update-serve-ssh.sh
EOF

cat > /etc/systemd/system/tailscale-serve-ssh.timer <<EOF
[Unit]
Description=Periodically refresh Tailscale SSH forward

[Timer]
OnBootSec=20s
OnUnitActiveSec=30s
Unit=tailscale-serve-ssh.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now tailscale-serve-ssh.timer
systemctl start tailscale-serve-ssh.service
systemctl --no-pager --full status tailscale-serve-ssh.timer | sed -n '1,10p'
echo ---
"$BASE/bin/tailscale" --socket="$SOCKET" serve status
REMOTE

echo "next: ./scripts/install-ssh-config.sh ${host}"
