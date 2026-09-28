#!/usr/bin/env bash
set -euo pipefail
LOG=/home/berdachuk/projects-coding-assist/bb/scripts/sync-opencode-to-87.log
exec > >(tee -a "$LOG") 2>&1
echo "==== $(date -Is) ===="
echo "host=$(hostname) ips=$(hostname -I)"
/home/berdachuk/projects-coding-assist/bb/scripts/sync-opencode-to-87.sh
echo EXIT:$?
