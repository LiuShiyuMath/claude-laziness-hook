# Claude Laziness Hook

Standalone Claude Code `Stop` hook that forces every assistant response to end
with a self-attested laziness report. The hook blocks the response if the report
is missing, malformed, or admits any lazy behavior.

This is not a Codex plugin. It is a plain hook script plus a Claude Code settings
fragment and installer.

## What It Enforces

Every final assistant message must end with:

```text
<laziness-self-report>
premature_stopping: false
permission_seeking: false
ownership_dodging: false
simplest_fix: false
reasoning_loop: false
known_limitation: false
</laziness-self-report>
```

The six booleans mean:

- `premature_stopping`: stopped before the task was genuinely handled
- `permission_seeking`: asked the user to approve a next step that should have been executed
- `ownership_dodging`: blamed environment, tools, or ambiguity before investigating
- `simplest_fix`: chose a shallow fix when root cause work was needed
- `reasoning_loop`: stayed in analysis without taking available action
- `known_limitation`: hid or glossed over a known limitation

Any `true` value blocks the response and asks Claude to continue in the same
turn. An all-false report approves silently.

## Install

```bash
./install.sh
```

The installer:

- copies `hooks/laziness-self-report.sh` to `~/.claude/scripts/hooks/`
- backs up `~/.claude/settings.json`
- adds an idempotent `Stop` hook entry with id `stop:laziness-self-report`

Manual settings fragment:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/scripts/hooks/laziness-self-report.sh\"",
            "timeout": 10
          }
        ],
        "id": "stop:laziness-self-report"
      }
    ]
  }
}
```

## Uninstall

```bash
./uninstall.sh
```

Remove the installed script too:

```bash
./uninstall.sh --remove-script
```

## Logs

Each Stop event appends one JSON line to:

```text
~/.claude/laziness/log.jsonl
```

Override the location with:

```bash
export LAZINESS_LOG_DIR=/tmp/laziness
export LAZINESS_LOG_FILE=/tmp/laziness/log.jsonl
```

## Test

```bash
./test/test-hook.sh
```

The test covers:

- all-false report approves
- missing report blocks
- any true report blocks

## Claude Code Stream JSON Smoke Test

`claude -h` shows that hooks are supplied with `--settings`, not a dedicated
hook directory flag. For stream JSON, Claude Code also requires `--verbose`.

Run the repo-local hook without installing it globally:

```bash
claudefast -p \
  --verbose \
  --output-format=stream-json \
  --include-hook-events \
  --settings config/repo-local-settings.json \
  --system-prompt 'Reply with exactly: OK plus a valid all-false laziness-self-report block. Do not use tools.' \
  'ping'
```

Expected output shape:

```json
{"type":"system","subtype":"init", "...": "..."}
{"type":"system","subtype":"hook_started","hook_name":"Stop","hook_event":"Stop", "...": "..."}
{"type":"system","subtype":"hook_response","hook_name":"Stop","hook_event":"Stop","stdout":"{\"continue\":true,\"suppressOutput\":true}\n", "...": "..."}
{"type":"result","subtype":"success","result":"pong\n\n<laziness-self-report>\n...", "...": "..."}
```

If the model omits or mangles the XML block, the expected stream includes one
blocked Stop response followed by a synthetic user feedback message:

```json
{"type":"system","subtype":"hook_response","hook_name":"Stop","hook_event":"Stop","stdout":"{\n  \"decision\": \"block\",\n  \"reason\": \"Your last message is missing or has a malformed <laziness-self-report> block ..."}
{"type":"user","message":{"content":[{"type":"text","text":"Stop hook feedback:\nYour last message is missing or has a malformed <laziness-self-report> block ..."}]}}
```

When user-level Claude hooks are also enabled, the stream may contain additional
`SessionStart`, `Stop`, or plugin hook events. The important signals for this
hook are the `decision:"block"` response on bad output and
`{"continue":true,"suppressOutput":true}` on valid output.

The required hook entry is also available as:

```text
patches/settings-stop-hook-entry.json
```
