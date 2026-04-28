#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$CLAUDE_DIR/settings.json}"
HOOK_TARGET="$CLAUDE_DIR/scripts/hooks/laziness-self-report.sh"
HOOK_ID="stop:laziness-self-report"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

if [[ -f "$SETTINGS_FILE" ]]; then
  backup="$SETTINGS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS_FILE" "$backup"
  tmp="$(mktemp)"
  jq --arg id "$HOOK_ID" '
    if .hooks.Stop then
      .hooks.Stop = (.hooks.Stop | map(select(.id != $id)))
    else
      .
    end
  ' "$SETTINGS_FILE" > "$tmp"
  mv "$tmp" "$SETTINGS_FILE"
  echo "updated settings: $SETTINGS_FILE"
  echo "backup: $backup"
fi

if [[ "${1:-}" == "--remove-script" ]]; then
  rm -f "$HOOK_TARGET"
  echo "removed hook script: $HOOK_TARGET"
else
  echo "left hook script in place: $HOOK_TARGET"
fi
