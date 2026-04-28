# Good Example: Duck tmux Investigation

This example highlights one useful behavior of the laziness hook: it turned a
shallow "no tmux session is running, what should I do?" answer into continued
root-cause investigation.

## Scenario

The assistant first summarized Duck as a Claude Code sandbox helper:

- nontechnical users can interact by typing instead of running shell commands
- it runs in `/tmp/duck-pulse-sandbox` instead of polluting real Claude config
- it uses sandbox/production visual signals and statusline badge flags
- the prior work supposedly added tmux mouse scrolling and 50k history

The user then asked the assistant to test whether tmux mouse scrolling worked
and to read from tmux to verify it.

## Highlight

The important sequence is:

1. The assistant checked `tmux list-sessions`, `tmux show-options -g mouse`,
   and running processes.
2. It saw no local tmux session and read the launch script.
3. It stopped too early, telling the user to start tmux or manually test.
4. The Stop hook blocked the response for a missing self-report.
5. The assistant retried but admitted `simplest_fix: true` and
   `known_limitation: true`.
6. The Stop hook blocked it again and required continued work in the same turn.
7. The assistant then searched the scripts, checked git history, inspected the
   parent submodule pointer, and verified the referenced submodule commit both
   locally and after fetching the remote.

That final investigation found the real blocker:

```text
Parent commit f7cba8f pointed at submodule commit 32543c5.
Commit 32543c5 did not exist locally.
After fetching origin, it still did not exist on the remote.
Therefore the earlier tmux mouse change was lost or never pushed.
```

## Hook Blocks

The first block caught a missing report:

```text
[laziness-guard] BLOCKED: missing or malformed self-report
```

The second block caught the assistant admitting it had taken the shallow path:

```text
simplest_fix: true
known_limitation: true
```

```text
[laziness-guard] BLOCKED: self-confessed laziness
```

## Before And After

```text
Before:
No local tmux session is running. Start duck-launch inside tmux or manually
open tmux to test. What do you want me to do?
```

```text
After:
The launch script only enables tmux mouse mode inside an existing tmux session,
the banner claimed scrolling was enabled unconditionally, and the parent repo
pointed at a missing submodule commit. The fix is to rebuild and publish the
tmux mouse change in the submodule before updating the parent pointer.
```

## Why This Is Good

The hook prevented a permission-seeking answer from becoming the final answer.
It forced the assistant to keep using available evidence until it could name a
specific blocker instead of handing the problem back to the user.

Raw cropped transcript:
`docs/examples/tmux-investigation-raw-transcript.txt`
