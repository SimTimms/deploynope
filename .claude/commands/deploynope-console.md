# /deploynope-console — DeployNOPE Console Monitor

> Re-prints the console monitor banner so the user can open a separate terminal pane
> to watch DeployNOPE messages in real time.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE @ Console`** while this command
> is active.

---

## When to Run

- The user wants to see the `tail -f` command again for the DeployNOPE sidecar console.
- The user has opened a new terminal and needs the command to start monitoring.

---

## Instructions

When this command is run:

1. Determine the current working directory (the worktree or repo root).
2. Create the log directory and file if they don't exist:

```shell
mkdir -p .deploynope
touch .deploynope/console.log
```

3. Print the following banner, replacing `<WORKDIR>` with the actual absolute path:

```
┌──────────────────────────────────────────────────────┐
│  🤓 DEPLOYNOPE CONSOLE                              │
│  Monitor deployment guardrails in a separate pane.   │
│                                                      │
│  Run in a new terminal:                              │
│                                                      │
│  cd <WORKDIR> && tail -f .deploynope/console.log     │
└──────────────────────────────────────────────────────┘
```

That is all this command does. It does not run any checks or gates.
