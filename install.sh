#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SETTINGS_FILE="${CLAUDE_SETTINGS_FILE:-$CLAUDE_DIR/settings.json}"
HOOK_TARGET="$CLAUDE_DIR/scripts/hooks/laziness-self-report.sh"
HOOK_COMMAND='bash "$HOME/.claude/scripts/hooks/laziness-self-report.sh"'
HOOK_ID="stop:laziness-self-report"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR/scripts/hooks"
install -m 0755 "$ROOT_DIR/hooks/laziness-self-report.sh" "$HOOK_TARGET"

if [[ ! -f "$SETTINGS_FILE" ]]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  printf '{}\n' > "$SETTINGS_FILE"
fi

backup="$SETTINGS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS_FILE" "$backup"

tmp="$(mktemp)"
jq \
  --arg cmd "$HOOK_COMMAND" \
  --arg id "$HOOK_ID" \
  '
  .hooks = (.hooks // {}) |
  .hooks.Stop = (
    (.hooks.Stop // [])
    | map(select(.id != $id))
    + [{
        matcher: "*",
        hooks: [{
          type: "command",
          command: $cmd,
          timeout: 10
        }],
        description: "Force Claude to self-attest 6 laziness booleans at every Stop. Block if the report is missing, malformed, or any boolean is true. Logs to ~/.claude/laziness/log.jsonl.",
        id: $id
      }]
  )
  ' "$SETTINGS_FILE" > "$tmp"
mv "$tmp" "$SETTINGS_FILE"

echo "installed hook script: $HOOK_TARGET"
echo "updated settings: $SETTINGS_FILE"
echo "backup: $backup"
