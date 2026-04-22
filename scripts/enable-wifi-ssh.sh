#!/bin/sh
set -eu

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")" && pwd
)

. "$SCRIPT_DIR/lib.sh"

echo "enabling Wi-Fi SSH over USB: ${RM_USB_HOST}"

rm_ssh "$RM_USB_HOST" "rm-ssh-over-wlan on"

echo "done"
