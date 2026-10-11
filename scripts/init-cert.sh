#!/usr/bin/env bash
# Устарело: используйте issue-certs.sh
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/issue-certs.sh" "$@"
