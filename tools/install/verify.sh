#!/usr/bin/env bash
# verify.sh — verify repo-managed Pi, AGY, skills, and protected credentials.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 -B "$SCRIPT_DIR/verify.py" "$@"
