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
