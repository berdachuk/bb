#!/usr/bin/env bash
set -euo pipefail

SRC="${HOME}/.config/opencode"
DEST_HOST="${1:-berdachuk@192.168.0.87}"
DEST_DIR="~/.config/opencode"

if [[ ! -d "$SRC" ]]; then
  echo "Missing source: $SRC" >&2
  exit 1
fi

echo "Source: $SRC"
echo "Dest:   $DEST_HOST:$DEST_DIR"
echo

ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$DEST_HOST" \
  'mkdir -p ~/.config/opencode/secrets'

rsync -av \
  --exclude='*.bak*' \
  --exclude='*.v2-broken*' \
  --exclude='opencode-v2-cost.jsonc' \
  "$SRC/" "$DEST_HOST:$DEST_DIR/"

echo
echo "Remote tree:"
ssh "$DEST_HOST" 'ls -la ~/.config/opencode; echo; ls -la ~/.config/opencode/secrets; echo; head -12 ~/.config/opencode/opencode.jsonc'

echo
echo "Done. Restart opencode/bb on the remote if it is already running."
