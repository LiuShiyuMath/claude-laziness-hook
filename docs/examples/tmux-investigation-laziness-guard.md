# Good Example: Forcing Root-Cause Follow-Through

This case study shows the laziness hook doing its intended job: blocking an
assistant response that stopped at a shallow limitation and forcing the agent to
continue investigating until it found a concrete root cause.

## Scenario

The user asked the assistant to test whether tmux mouse scrolling worked and to
read from tmux to verify the result.

The assistant initially ran:

```text
tmux list-sessions
tmux show-options -g mouse
ps aux | grep -E 'tmux|screen'
```

Those checks showed no local tmux session. The assistant then read the launch
script and produced this weak answer:

```text
There is no local tmux session running.
The script only enables mouse mode when TMUX is set.

You need to:
1. Start duck-launch inside tmux
2. Or manually open tmux to test

What do you want me to do?
```

That answer had two problems:

- It asked the user for permission instead of continuing available verification.
- It treated the missing local tmux session as the end of the investigation.

## First Block: Missing Report

The Stop hook blocked the message because it did not include the required
self-report block:

```text
[laziness-guard] BLOCKED: missing or malformed self-report
```

The hook instructed the assistant to append:

```text
<laziness-self-report>
premature_stopping: <true|false>
permission_seeking: <true|false>
ownership_dodging: <true|false>
simplest_fix: <true|false>
reasoning_loop: <true|false>
known_limitation: <true|false>
</laziness-self-report>
```

## Second Block: Self-Confessed Laziness

The assistant tried again, but admitted:

```text
simplest_fix: true
known_limitation: true
```

The hook blocked the response again:

```text
[laziness-guard] BLOCKED: self-confessed laziness
```

The important behavior is that the hook did not let the assistant finish with a
known shallow answer. It forced more work in the same turn.

## Better Follow-Through

After the second block, the assistant continued investigating:

```text
Search for tmux and mouse handling in the relevant scripts.
Read the launch script.
Inspect git history for tmux, mouse, and scroll commits.
Check the parent repository's submodule pointer.
Check whether the referenced submodule commit exists locally.
Fetch the submodule remote and check whether the commit exists there.
```

That extra work found a concrete root cause:

```text
The parent commit pointed at submodule commit 32543c5.
That submodule commit did not exist locally.
After fetch, it still did not exist on the remote.
Therefore the earlier tmux mouse change had been lost or never pushed.
```

## Why This Is A Good Example

The hook changed the assistant behavior from:

```text
I cannot test because no tmux session exists. What should I do?
```

to:

```text
I checked the surrounding scripts, git history, submodule pointer, and remote
state. The real blocker is a missing submodule commit, so the fix is to rebuild
and publish the tmux mouse change in the submodule before updating the parent.
```

This is the intended value of the hook: it makes shallow stopping visible and
turns it into more concrete investigation before the user has to intervene.
