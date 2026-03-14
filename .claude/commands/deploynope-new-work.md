# /deploynope-new-work — Starting New Work Checklist

> Run this when starting a new task, feature, fix, or piece of work. It runs the
> worktree check, branching policy, and branch drift check before you create a branch.
>
> For the full deployment ruleset (deployment process, staging, master reset), run
> `/deploynope-deploy` first.
>
> **Framework Visibility:** Tag every response with **`🤓 Protected by DeployNOPE`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## When to Run

- You are about to start a new feature, hotfix, chore, or ticket.
- You want to confirm worktree, branch name, base branch, and branch drift before creating a branch.

---

## Instructions

When this command is run, perform the following in order:

### 1. Check for Other Claude Instances (and worktree)

Check whether another Claude instance is already working in this repository:

```shell
ps aux | grep -i claude | grep -v grep
```

- If another Claude process is found **and no worktree is in use**, stop and warn the user:

  > "Warning: another Claude instance appears to be running. If it is working in the
  > same repository without a separate worktree, proceeding could cause branch conflicts
  > or overwrite in-progress work. Please confirm it is safe to continue, or set up a
  > worktree to isolate this work."

  **[HUMAN GATE]** — wait for explicit confirmation before proceeding.

- If a worktree is already in use for this work, it is safe to continue.

### 2. Check if a new worktree is appropriate

Ask the user:

> "Would you like to work in a new worktree for this, or continue in the current directory?"

### 3. Ask for the branch name

**Never invent a branch name.** Ask the user what the branch should be called.

### 4. Ask which branch to base it on (branching policy)

Suggest the most appropriate base branch according to the deployment process, and explain why:

| Work type | Recommended base | Reason |
|---|---|---|
| Feature release | `master` | Release branches are cut from master |
| Hotfix | `master` | Hotfixes branch directly from production |
| Ticket/feature branch | The current release branch (e.g. `6.51.0`) | Ticket branches feed into the release branch |
| Chore / config | `master` | All work types follow the same staging → master process |

Present the recommendation with a short explanation, then offer alternatives:

> "Based on the deployment process, I'd recommend branching from `master` because [reason].
> Would you like to use that, or a different base?
> 1. `master` ← recommended
> 2. `development`
> 3. Other — please specify"

### 5. Run the branch drift check

Before creating the branch, check:

1. **`master` vs `staging`** — commits on `master` not in `staging`?
2. **`master` vs `development`** — commits on `master` not in `development`?

```shell
git fetch origin
git log origin/staging..origin/master --oneline
git log origin/development..origin/master --oneline
```

If either shows commits, warn the user:

> "Warning: `master` has commits not in `development` (or `staging`). A previous release
> may not have completed the full deployment process. Please resolve this before starting
> a new feature branch."

Do not proceed until the user has acknowledged the warning.

### 6. Pull latest on the base branch (before creating the branch)

Remind the user (or do it after confirmation):

```shell
git checkout <base-branch>
git pull origin <base-branch>
```

Never branch off or merge from a stale local branch.

---

## After the checklist

Once worktree, branch name, base branch, and drift check are confirmed, you may create the branch. **Creating a branch** remains a human gate — confirm the branch name and base branch before running `git checkout -b <name> <base>`.

For the full deployment ruleset (staging contention, master reset, cross-repo checks, etc.), ensure `/deploynope-deploy` has been run in this session.
