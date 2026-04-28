#!/usr/bin/env bash
# Claude Code Stop hook that requires a laziness self-report block.
#
# It blocks the assistant response when:
# - the last assistant message has no <laziness-self-report> block
# - the block is malformed or missing any required boolean field
# - any required field is set to true
#
# It approves silently when all fields are present and false.

set -uo pipefail

LOG_DIR="${LAZINESS_LOG_DIR:-$HOME/.claude/laziness}"
LOG_FILE="${LAZINESS_LOG_FILE:-$LOG_DIR/log.jsonl}"
mkdir -p "$LOG_DIR"

input="$(cat)"
transcript_path="$(printf '%s' "$input" | jq -r '.transcript_path // empty')"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

emit_block_missing() {
  local detail="$1"

  jq -cn \
    --arg ts "$ts" \
    --arg sid "$session_id" \
    --arg detail "$detail" \
    '{ts:$ts, session_id:$sid, report_present:false, action:"block_missing_report", detail:$detail}' \
    >> "$LOG_FILE"

  jq -n \
    --arg reason "Your last message is missing or has a malformed <laziness-self-report> block ($detail). Append this exact block to the END of every response before stopping:

<laziness-self-report>
premature_stopping: <true|false>
permission_seeking: <true|false>
ownership_dodging: <true|false>
simplest_fix: <true|false>
reasoning_loop: <true|false>
known_limitation: <true|false>
</laziness-self-report>

For each category, honestly evaluate whether your last work exhibited that pattern. Re-emit your message with the report appended. If any boolean is true, continue the work in the same turn instead of stopping." \
    --arg sysmsg "[laziness-guard] BLOCKED: missing or malformed self-report ($detail)" \
    '{decision:"block", reason:$reason, systemMessage:$sysmsg}'
  exit 0
}

emit_block_lazy() {
  local signals_csv="$1"
  local signals_json="$2"

  jq -cn \
    --arg ts "$ts" \
    --arg sid "$session_id" \
    --argjson sig "$signals_json" \
    --arg signals "$signals_csv" \
    '{ts:$ts, session_id:$sid, report_present:true, lazy_signals:$sig, any_lazy:true, action:"block_lazy", true_signals:$signals}' \
    >> "$LOG_FILE"

  jq -n \
    --arg reason "Your self-report admits laziness in: $signals_csv. Reject your last message and continue the work in the same turn. Do not ask permission. Investigate root cause before disclaiming ownership. Finish the task or name a hard, specific blocker. Re-emit with all booleans false only after actually fixing the lazy behavior." \
    --arg sysmsg "[laziness-guard] BLOCKED: self-confessed laziness ($signals_csv)" \
    '{decision:"block", reason:$reason, systemMessage:$sysmsg}'
  exit 0
}

emit_approve() {
  local signals_json="$1"

  jq -cn \
    --arg ts "$ts" \
    --arg sid "$session_id" \
    --argjson sig "$signals_json" \
    '{ts:$ts, session_id:$sid, report_present:true, lazy_signals:$sig, any_lazy:false, action:"approve"}' \
    >> "$LOG_FILE"

  printf '{"continue":true,"suppressOutput":true}\n'
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  printf '{"decision":"block","reason":"laziness hook requires jq on PATH","systemMessage":"[laziness-guard] BLOCKED: jq missing"}\n'
  exit 0
fi

if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
  emit_block_missing "transcript_path missing or unreadable"
fi

extract_last_text() {
  jq -rs '
    [.[] | select(.type == "assistant")
          | select((.message.content // []) | any(.type == "text"))]
    | last
    | (.message.content // [])
    | map(select(.type == "text") | .text)
    | join("\n")
  ' "$transcript_path" 2>/dev/null
}

last_text=""
sleep 0.3
for _ in 1 2 3 4 5 6 7 8 9 10; do
  candidate="$(extract_last_text || true)"
  if [[ -n "$candidate" ]]; then
    last_text="$candidate"
    if printf '%s' "$candidate" | grep -q '<laziness-self-report>'; then
      break
    fi
  fi
  sleep 0.3
done

if [[ -z "$last_text" ]]; then
  emit_block_missing "no text content in last assistant message"
fi

report_body="$(printf '%s' "$last_text" | awk '
  /<laziness-self-report>/ { found=1; next }
  /<\/laziness-self-report>/ { found=0; exit }
  found { print }
')"

if [[ -z "$report_body" ]]; then
  emit_block_missing "no <laziness-self-report> block found"
fi

parse_field() {
  local name="$1"
  printf '%s\n' "$report_body" \
    | grep -iE "^[[:space:]]*${name}[[:space:]]*:" \
    | head -1 \
    | sed -E 's/^[^:]*:[[:space:]]*([A-Za-z]+).*/\1/' \
    | tr '[:upper:]' '[:lower:]'
}

sig_premature_stopping="$(parse_field premature_stopping)"
sig_permission_seeking="$(parse_field permission_seeking)"
sig_ownership_dodging="$(parse_field ownership_dodging)"
sig_simplest_fix="$(parse_field simplest_fix)"
sig_reasoning_loop="$(parse_field reasoning_loop)"
sig_known_limitation="$(parse_field known_limitation)"

for pair in \
  "premature_stopping:$sig_premature_stopping" \
  "permission_seeking:$sig_permission_seeking" \
  "ownership_dodging:$sig_ownership_dodging" \
  "simplest_fix:$sig_simplest_fix" \
  "reasoning_loop:$sig_reasoning_loop" \
  "known_limitation:$sig_known_limitation"
do
  field_name="${pair%%:*}"
  field_value="${pair#*:}"
  if [[ "$field_value" != "true" && "$field_value" != "false" ]]; then
    emit_block_missing "field '$field_name' missing or value not true|false"
  fi
done

true_signals=""
add_if_true() {
  local name="$1"
  local value="$2"
  if [[ "$value" == "true" ]]; then
    if [[ -z "$true_signals" ]]; then
      true_signals="$name"
    else
      true_signals="$true_signals,$name"
    fi
  fi
}

add_if_true premature_stopping "$sig_premature_stopping"
add_if_true permission_seeking "$sig_permission_seeking"
add_if_true ownership_dodging "$sig_ownership_dodging"
add_if_true simplest_fix "$sig_simplest_fix"
add_if_true reasoning_loop "$sig_reasoning_loop"
add_if_true known_limitation "$sig_known_limitation"

signals_json="$(jq -n \
  --arg ps "$sig_premature_stopping" \
  --arg pk "$sig_permission_seeking" \
  --arg od "$sig_ownership_dodging" \
  --arg sf "$sig_simplest_fix" \
  --arg rl "$sig_reasoning_loop" \
  --arg kl "$sig_known_limitation" \
  '{
    premature_stopping: ($ps == "true"),
    permission_seeking: ($pk == "true"),
    ownership_dodging: ($od == "true"),
    simplest_fix: ($sf == "true"),
    reasoning_loop: ($rl == "true"),
    known_limitation: ($kl == "true")
  }')"

if [[ -n "$true_signals" ]]; then
  emit_block_lazy "$true_signals" "$signals_json"
fi

emit_approve "$signals_json"
