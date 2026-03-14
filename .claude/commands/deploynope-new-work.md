# /deploynope-new-work — Starting New Work Checklist

> Run this when starting a new task, feature, fix, or piece of work. It runs the
> worktree check, branching policy, and branch drift check before you create a branch.
>
> For the full deployment ruleset (deployment process, staging, <production-branch> reset), run
> `/deploynope-deploy` first.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE @ New Work`** while this command
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
| Feature release | `<production-branch>` | Release branches are cut from <production-branch> |
| Hotfix | `<production-branch>` | Hotfixes branch directly from production |
| Ticket/feature branch | The current release branch (e.g. `6.51.0`) | Ticket branches feed into the release branch |
| Chore / config | `<production-branch>` | All work types follow the same <staging-branch> → <production-branch> process |

**Before suggesting a release branch as a base**, fetch from the remote and verify it
has not already been released:

```shell
git fetch origin
git tag -l 'v*' --sort=-v:refname
gh release list --limit 10
```

If a tag or GitHub Release exists matching the release branch version, that branch has
already been deployed. **Do not suggest it as a base.** Instead, prompt the user to create
a new release branch:

> "The release branch `<version>` has already been deployed (tag `v<version>` exists).
> Would you like to create a new release branch? The next available version is `<next-version>`."

Present the recommendation with a short explanation, then offer alternatives:

> "Based on the deployment process, I'd recommend branching from `<production-branch>` because [reason].
> Would you like to use that, or a different base?
> 1. `<production-branch>` ← recommended
> 2. An existing release branch (e.g. `release/1.2.0`) — for ticket/feature work feeding into a release
> 3. Other — please specify"

**Warning:** Do **not** offer `<development-branch>` as a base branch. The `<development-branch>` branch is
only updated by merging the release branch into it **after** production deployment. Branching
from `<development-branch>` creates a mismatch: the PR hook will block PRs targeting `<development-branch>`,
and the work cannot follow the correct release flow (`feature → release → <staging-branch> → <production-branch> → development`).

If the user's work is a feature or ticket and no release branch exists yet, prompt them to
create one first:

> "There's no active release branch. Would you like to create one (e.g. `release/X.Y.Z`)
> from `<production-branch>` first? Feature branches should target a release branch, not `<development-branch>`."

### 5. If creating a release branch, run the release version check

If the branch name follows a version pattern (e.g. `X.Y.Z`), fetch from the remote and
check all existing versions before proceeding:

```shell
git fetch origin
git tag -l 'v*' --sort=-v:refname
git branch -r | grep -E 'origin/[0-9]+\.[0-9]+\.[0-9]+'
gh release list --limit 10
```

- The version **must be higher** than any existing tag, release, or version-patterned branch.
- If the user's chosen version conflicts, warn them and suggest the next available version.
- If the user provides only a major version (e.g. "1"), look up the latest `1.x.y` and
  suggest the next minor bump.
- See `/deploynope-deploy` § Release Version Check for full details.

### 6. Run the branch drift check

Before creating the branch, check:

1. **`<production-branch>` vs `<staging-branch>`** — commits on `<production-branch>` not in `<staging-branch>`?
2. **`<production-branch>` vs `<development-branch>`** — commits on `<production-branch>` not in `<development-branch>`?

```shell
git fetch origin
git log origin/<staging-branch>..origin/<production-branch> --oneline
git log origin/<development-branch>..origin/<production-branch> --oneline
```

If either shows commits, warn the user:

> "Warning: `<production-branch>` has commits not in `<development-branch>` (or `<staging-branch>`). A previous release
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

For the full deployment ruleset (staging contention, <production-branch> reset, cross-repo checks, etc.), ensure `/deploynope-deploy` has been run in this session.
