# /deploynope-console — DeployNOPE Console Monitor

> Re-prints the console monitor banner so the user can open a separate terminal pane
> to watch DeployNOPE messages in real time.
>
> **Framework Visibility:** Tag every response with **`🤓 DN <context> · Console`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## When to Run

- The user wants to see the `tail -f` command again for the DeployNOPE sidecar console.
- The user has opened a new terminal and needs the command to start monitoring.

---

## Instructions

When this command is run:

1. Determine the current working directory (the worktree or repo root).
2. Determine the worktree name (the last segment of the worktree path, e.g. `hook-enforcement-hardening`).
   If not in a worktree, use the repo directory name.
3. Create the log directory and file if they don't exist:

```shell
mkdir -p .deploynope
touch .deploynope/console.log
```

4. Write a seed message so `tail -f` shows immediate output:

```shell
echo "[$(date '+%H:%M:%S')] 🤓 DN <context> · Console — Listening on <worktree-name>" >> .deploynope/console.log
```

5. Print the following banner, replacing `<WORKDIR>` with the actual absolute path and
   `<WORKTREE>` with the worktree/directory name:

**🤓 DEPLOYNOPE CONSOLE**
Worktree: `<WORKTREE>`
Monitor deployment guardrails in a separate pane.

Run in a new terminal:
1. `cd <WORKDIR>`
2. `tail -f .deploynope/console.log`

That is all this command does. It does not run any checks or gates.
