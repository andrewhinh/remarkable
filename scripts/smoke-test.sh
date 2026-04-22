#!/bin/sh
set -eu

ROOT_DIR=$(
  CDPATH= cd -- "$(dirname "$0")/.." && pwd
)

cd "$ROOT_DIR"

for script in scripts/*.sh; do
  sh -n "$script"
done

echo "smoke ok"
