#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export LAZINESS_LOG_DIR="$TMP_DIR/logs"

make_transcript() {
  local text="$1"
  local file="$2"
  jq -cn --arg text "$text" '{
    type: "assistant",
    message: {
      content: [
        {type: "text", text: $text}
      ]
    }
  }' > "$file"
}

run_hook() {
  local transcript="$1"
  jq -cn --arg transcript "$transcript" --arg sid "test-session" '{
    transcript_path: $transcript,
    session_id: $sid
  }' | "$ROOT_DIR/hooks/laziness-self-report.sh"
}

good_text='Done.

<laziness-self-report>
premature_stopping: false
permission_seeking: false
ownership_dodging: false
simplest_fix: false
reasoning_loop: false
known_limitation: false
</laziness-self-report>'

bad_text='Done.'
lazy_text='Done.

<laziness-self-report>
premature_stopping: true
permission_seeking: false
ownership_dodging: false
simplest_fix: false
reasoning_loop: false
known_limitation: false
</laziness-self-report>'

make_transcript "$good_text" "$TMP_DIR/good.jsonl"
make_transcript "$bad_text" "$TMP_DIR/bad.jsonl"
make_transcript "$lazy_text" "$TMP_DIR/lazy.jsonl"

good_result="$(run_hook "$TMP_DIR/good.jsonl")"
bad_result="$(run_hook "$TMP_DIR/bad.jsonl")"
lazy_result="$(run_hook "$TMP_DIR/lazy.jsonl")"

printf '%s\n' "$good_result" | jq -e '.continue == true and .suppressOutput == true' >/dev/null
printf '%s\n' "$bad_result" | jq -e '.decision == "block"' >/dev/null
printf '%s\n' "$lazy_result" | jq -e '.decision == "block"' >/dev/null
test "$(wc -l < "$LAZINESS_LOG_DIR/log.jsonl" | tr -d ' ')" = "3"

echo "ok"
