# Deployment & Release Ruleset

> Loaded via `/deploynope-deploy`. Applies to all deployment, release, branching, versioning,
> code review, and Confluence tasks.
>
> - **Backend:** `{owner}/{backend-repo}`
> - **Frontend:** `{owner}/{frontend-repo}`

---

## Configuration

Check for `.deploynope.json` in the current working directory. If it exists, read it and
use its values in place of all placeholders throughout this ruleset (see `/deploynope-configure`
for the full mapping). If it does not exist, use the placeholder names as-is and suggest:

> "Tip: run `/deploynope-configure` to set up your repo names, branch names, and Confluence
> details so they're filled in automatically."

---

## Framework Visibility

**Every response** produced while DeployNOPE rules are active must begin with the tag
**`Protected by DeployNOPE`** so the user can immediately see which framework is driving decisions.

- Tag every message — not just the first one — for the duration of the workflow.
- If a DeployNOPE command is invoked alongside another framework (e.g. Agile V), tag
  both: **`Protected by DeployNOPE`** **`[Agile V]`**.
- If an action *should* be governed by DeployNOPE but you are about to skip it, state
  that explicitly rather than proceeding silently.

This rule exists because silent framework compliance (or non-compliance) is invisible
to the user and has caused missed steps in the past.

---

## ⚠️ Incomplete Picture Warning

If planning, reviewing, or executing a deployment without access to any of the following,
**stop immediately and warn the user** before continuing:

- The corresponding frontend or backend repository
- AWS Secrets Manager or other infrastructure config
- Open PRs or branch state on the other repo
- Any external system relevant to the task (CodePipeline status, Jira tickets, etc.)

State clearly what is missing and what impact it may have before proceeding.

---

## Suggesting Next Steps

**Never suggest pushing directly to `master`.** All changes must go through
the full deployment process (staging reset → validate → master reset) unless
the user explicitly states exceptional circumstances.

When a branch is ready to move forward, always present the deployment process table
with the current position marked, and ask:

> "Shall we start the deployment process?"

Example:

| Step | Action | Status |
|------|--------|--------|
| 1 | Feature branches merged into release branch | ✅ Done |
| 2 | Sync release branch with `master` | ✅ Done |
| 3 | Confirm release branch is ready | ✅ Done |
| 4 | Staging contention check | ⬅️ Next |
| 5 | Claim staging | — |
| 6 | Reset `staging` to match release branch | — |
| 7 | Validate on staging | — |
| 8 | Cross-repo version parity check | — |
| 9 | Reset `master` to match `staging` | — |
| 10 | Confirm CodePipeline healthy | — |
| 11 | Create GitHub Release (both repos) | — |
| 12 | Merge release branch into `development` | — |
| 13 | Clear staging | — |
| 14 | Write Confluence release notes | — |

Always mark where we currently are (⬅️ Next) and what's already done (✅ Done).
Update the table as steps are completed throughout the conversation.

---

## Pre-Flight Checks

Before any deployment, branch, or code review work, run these checks first:

### 1. Pull Latest Changes

Always pull the latest changes to the target/base branch before working on it locally:

```shell
git checkout <target-branch>
git pull origin <target-branch>
```

If the local branch is behind origin, pull before proceeding. Never branch off or
merge from a stale local branch.

### 2. Check for Other Claude Instances

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

---

## Starting New Work

Whenever a new task, feature, fix, or piece of work begins — before doing anything else, run the starting-new-work checklist. You can also run **`/deploynope-new-work`** to run this checklist explicitly.

1. **Check if a new worktree is appropriate.** Ask the user:
   > "Would you like to work in a new worktree for this, or continue in the current directory?"

2. **Ask for the branch name** — never invent one.

3. **Ask which branch to base it on.** Suggest the most appropriate base branch according
   to the deployment process document, and explain why:

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

4. **Run the branch drift check** before creating the branch (see below).

---

## Human Gates — Mandatory Pause Points

Stop and wait for explicit written confirmation before:

1. **Creating a branch** — confirm the branch name and base branch.
2. **Any `git push`** — always ask "Shall I push this?"
3. **Any force-push or reset** — state exactly what will be overwritten and confirm.
4. **Resetting `staging`** — must pass the staging contention check first (see below), then confirm.
5. **Resetting `master`** — confirm: "Just to confirm — you want me to reset `master` to match `staging`?"
6. **Removing worktrees** — list what will be removed and confirm.
7. **After staging validation** — wait for explicit "it's validated" sign-off before resetting `master`.
8. **Creating a GitHub Release** — confirm the tag and which repos to release.
9. **Any deployment step after 2:00 PM** — warn and ask for confirmation (see Deployment Timing).
10. **Starting a new feature branch** — run branch drift check first (see below).

---

## Staging Contention — Claim & Clear

Staging is a shared resource. Before resetting it, two checks must pass:

### Before resetting staging

**Check 1: Unreleased commits**

```shell
git fetch origin
git log origin/master..origin/staging --oneline
```

If this shows commits, staging has work that hasn't reached production yet.
**Do not reset staging** — someone else's validated work would be lost.

**Check 2: Active claim tag**

```shell
git tag -l "staging/active"
```

If the `staging/active` tag exists, another developer or release has claimed staging.
Check who claimed it:

```shell
git tag -n1 "staging/active"
```

If either check fails, **stop and warn the user**. Do not proceed until the team
confirms it is safe.

### Claiming staging

When both checks pass and the user has confirmed:

```shell
git tag -a staging/active -m "Claimed by <name> for <branch> on <date>" origin/staging
git push origin staging/active
```

Prompt the user to notify the team in Slack that staging has been claimed and for which branch.

### Clearing staging

After master has been reset and the deployment is confirmed healthy:

```shell
git tag -d staging/active
git push origin :staging/active
```

Prompt the user to notify the team in Slack that staging is now clear and available.

> **Do not clear staging until master has been reset and deployment is confirmed.**
> The claim persists from the moment staging is taken until the work is live in production.

---

## Resetting `master` — Branch Protection Toggle

`master` has GitHub branch protection enabled with force-pushes **disabled by default**.
When the deployment process reaches the master reset step, Claude must temporarily
enable force-pushes, perform the reset, and immediately re-disable them.

### ⚠️ Worktree Safety Check

**Before resetting `master`, verify you are in the main repository clone — not a worktree.**

```shell
git rev-parse --git-dir
```

- If the output is `.git` — you are in the main clone. Safe to proceed.
- If the output contains `/worktrees/` — you are in a worktree. **STOP.**

**Do not run the master reset from a worktree.** Running `git checkout master` inside
a worktree will fail if `master` is already checked out in the main clone (`fatal:
'master' is already checked out at ...`). Even if it didn't fail, resetting master
from a worktree risks operating on the wrong working directory.

If you are in a worktree, switch to the main repository clone first:

> "I'm currently in a worktree. The master reset must be run from the main repository
> clone at `<path>`. Please switch to that directory, or confirm I should proceed
> from there."

**[HUMAN GATE]** — Wait for confirmation before continuing.

### Procedure

**[HUMAN GATE]** — Confirm with the user before starting: "Ready to reset `master` to
match `staging`. This will temporarily enable force-push on `master`, perform the reset,
and immediately re-lock it. Proceed?"

**Step 1: Enable force-push**

```shell
gh api repos/{owner}/{repo}/branches/master/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": true,
  "allow_deletions": false
}
EOF
```

Confirm the response shows `"allow_force_pushes": { "enabled": true }`.

**Step 2: Reset master**

```shell
git checkout master
git reset --hard staging
git push --force-with-lease origin master
```

**Step 3: Re-lock master (immediately)**

```shell
gh api repos/{owner}/{repo}/branches/master/protection -X PUT --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

Confirm the response shows `"allow_force_pushes": { "enabled": false }`.

> **⚠️ If the reset fails (Step 2), still run Step 3 immediately** to re-lock master.
> Never leave master unprotected. If Step 3 also fails, warn the user immediately
> so they can manually re-enable protection in GitHub settings.

The `{owner}/{repo}` placeholders should be replaced with your actual repository names
(e.g. `my-org/backend` and `my-org/frontend`).

---

## Git & Branching Rules

- **Never push without permission.**
- **Never reset `master` without completing the staging process first.**
- **All changes reach `master` via a controlled reset from `staging`.** No direct pushes, no PRs to master.
- **`master` is protected.** Force-pushes are disabled by default and only temporarily enabled during the controlled reset (see above).
- **Always ask what branch to branch off of** before creating a new branch.
- **Always ask for the branch name** — never invent one.
- **Always use `--force-with-lease`** instead of `--force`.
- **Always run the staging contention check** before resetting staging.
- **All work types follow the same process** — feature releases, hotfixes, and chore/config changes all go through staging → master reset. No shortcuts.
- Branches are created off `master` unless explicitly told otherwise.

---

## Branch Drift Check

Before creating any new release or feature branch, check:

1. **`master` vs `staging`** — commits on `master` not in `staging`?
2. **`master` vs `development`** — commits on `master` not in `development`?

If discrepancies are found, warn the user:

> "Warning: `master` has commits not in `development` (or `staging`). A previous release
> may not have completed the full deployment process. Please resolve this before starting
> a new feature branch."

Do not proceed until the user has acknowledged the warning.

---

## Deployment Timing

**Do not initiate any deployment step after 2:00 PM.** This includes:
- Resetting `staging`
- Resetting `master`
- Creating a GitHub Release

If attempted after 2:00 PM, warn the user:

> "Warning: it is after 2:00 PM. Deployments outside the safe window increase risk
> during peak traffic hours. Do you want to proceed?"

Wait for explicit written confirmation before continuing.

---

## Deployment Process

All work types follow the same staging → master reset process.

### Feature Release

1. Feature ticket branches → release branch (e.g. `6.51.0`) via PR
2. Sync release branch with `master` (`git merge master`)
3. **[HUMAN GATE]** Confirm release branch is ready
4. **[STAGING CHECK]** Run staging contention check (unreleased commits + active claim)
5. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
6. Reset `staging` to match the release branch: `git reset --hard <release-branch>`
7. **[HUMAN GATE]** Validate on staging — wait for explicit "it's validated" sign-off
8. **[CROSS-REPO CHECK]** Confirm frontend/backend version parity (see Cross-Repo Rules)
9. **[HUMAN GATE]** Confirm before resetting `master` — CodePipeline deploys automatically
10. Reset `master` to match `staging`: `git reset --hard staging`
11. **Deploy backend first** — confirm CodePipeline healthy before resetting frontend `master`
12. Create GitHub Release on **both** repos
13. Merge release branch into `development`
14. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
15. Write Confluence release notes
16. **[BRANCH ANALYSIS]** Run post-deployment branch alignment check (see below)

### Hotfix

1. Branch `6.XX.Y` from `master`
2. **[STAGING CHECK]** Run staging contention check
3. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
4. Reset `staging` to match hotfix branch
5. **[HUMAN GATE]** Validate on staging
6. **[CROSS-REPO CHECK]** Confirm frontend/backend version parity
7. Reset `master` to match `staging`
8. **Deploy backend first** — confirm CodePipeline healthy before resetting frontend `master`
9. Create GitHub Release on both repos
10. Merge hotfix branch into `development`
11. Notify in-flight feature branches to pull from `development`
12. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
13. Write Confluence release notes
14. **[BRANCH ANALYSIS]** Run post-deployment branch alignment check (see below)

### Chore / Config

1. Branch from `master` (e.g. `chore/claude-config`)
2. Do the work, commit, and push
3. **[STAGING CHECK]** Run staging contention check
4. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
5. Reset `staging` to match chore branch
6. **[HUMAN GATE]** Validate on staging
7. Reset `master` to match `staging`
8. Confirm deployment is healthy
9. Merge `master` into `development`
10. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
11. **[BRANCH ANALYSIS]** Run post-deployment branch alignment check (see below)

---

## Cross-Repo Rules

**Every code review and deployment task must always consider both repos together.**
Never review or deploy either repo in isolation.

### Version Parity

Frontend and backend must **always be on the same version number** in production,
even if one has no code changes.

Before any `master` reset:
1. Check `package.json` version on both repos.
2. If they do not match, **stop and warn the user**.
3. If one repo has no code changes, it still needs a version bump and GitHub Release.

### Pre-Production Cross-Repo Check

Before any production deployment, confirm:
- What is the current version on the other repo?
- Does it match the version being deployed?
- Is there a corresponding release in progress on the other repo?
- If both repos have changes, is the backend being deployed first?

State the answers before proceeding.

### Code Reviews

Always check both repos for related changes before beginning any review — API contracts,
auth flows, endpoint changes, and version alignment must all be considered together.

If access to either repo is missing, stop and flag it (see Incomplete Picture Warning).

---

## Versioning

- Format: `MAJOR.MINOR.PATCH` (e.g. `6.51.0`). If user writes `6.5.1.0` they mean `6.51.0`.
- Update `package.json` for every release or hotfix in any repo with code changes.
- Regenerate lock file: `npm install` (backend) or `npm install --legacy-peer-deps` (frontend).
- Commit `package.json` and `package-lock.json` together.
- Both repos must always have matching version numbers in production.

---

## Confluence Release Notes

Write a release note page **after every production deployment**.

- **Space:** `{confluence-space-key}`
- **Space ID:** `{confluence-space-id}`
- **Cloud ID:** `{confluence-cloud-id}`
- **Release notes folder ID:** `{confluence-folder-id}`
- **Format:** Match existing pages — Branch, Author, Date, Jira ticket(s),
  What Changed, Deployment Checks, Notes.
- Confirm content with the user before publishing.

---

## Merge Conflict Resolution

- **Always ask which side to prefer** before resolving — never assume.
- When a release branch conflicts with `staging` or `master`, prefer the release branch
  unless there is a clear reason not to.
- State what you are resolving and why before committing.

---

## Post-Deployment Branch Alignment Check

This is the final step of every deployment. Run it on **both** repos to confirm
everything is in sync. Do not skip this step.

### Checks

```shell
git fetch origin --quiet

# 1. Branch alignment — all three should be identical
git log origin/master..origin/staging --oneline
git log origin/staging..origin/master --oneline
git log origin/master..origin/development --oneline
git log origin/development..origin/master --oneline

# 2. Version on each branch
for branch in origin/master origin/staging origin/development; do
  echo "$branch: $(git show $branch:package.json | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo 'N/A')"
done

# 3. Staging claim should be clear
git tag -l "staging/active"

# 4. Latest GitHub Release should match production version
gh release list --limit 1

# 5. Open PRs targeting key branches
gh pr list --state open
```

Run the above on both repos (backend and frontend).

### Report format

**Branch Alignment Report**
_Date: `<today>` | Production version: `<version>`_

#### Backend

| Check | Status | Detail |
|-------|--------|--------|
| `master` = `staging` | ✅ / ❌ | Identical / X commits apart |
| `master` = `development` | ✅ / ❌ | Identical / X commits apart |
| Version: `master` / `staging` / `development` | ✅ / ❌ | All `<version>` / Mismatch |
| Staging claim | ✅ Clear / ⚠️ Active | Tag details if active |
| Latest GitHub Release | ✅ / ❌ | `<tag>` matches / Behind |
| Open PRs | ℹ️ | X open — flag any targeting key branches |

#### Frontend

| Check | Status | Detail |
|-------|--------|--------|
| `master` = `staging` | ✅ / ❌ | Identical / X commits apart |
| `master` = `development` | ✅ / ❌ | Identical / X commits apart |
| Version: `master` / `staging` / `development` | ✅ / ❌ | All `<version>` / Mismatch |
| Staging claim | ✅ Clear / ⚠️ Active | Tag details if active |
| Latest GitHub Release | ✅ / ❌ | `<tag>` matches / Behind |
| Open PRs | ℹ️ | X open — flag any targeting key branches |

#### Cross-Repo

| Check | Status | Detail |
|-------|--------|--------|
| Backend version = Frontend version | ✅ / ❌ | Both on `<version>` / Mismatch |
| Backend release = Frontend release | ✅ / ❌ | Both tagged `<version>` / Mismatch |

If everything is aligned:

> "All branches are aligned across both repos. Production, staging, and development
> are all on version `<version>`. Ready for new work."

If issues are found, list them in priority order with recommended actions.

---

## Commit Confirmation Format

**No commit may be executed without showing this confirmation block first** — regardless
of whether you or the user initiates the commit. This includes when the user says "yes",
"let's commit", "commit this", "go ahead", or any other approval. The confirmation block
is the last step before `git commit` runs.

**Flow:**
1. User approves or requests a commit (or you propose one).
2. Gather the current branch, version, and draft a commit message.
3. Display the confirmation block below.
4. Wait for the user to approve or request changes.
5. Only after explicit approval, run `git commit`.

**Confirmation block format:**

> **`Protected by DeployNOPE`**
>
> | | |
> |---|---|
> | **Branch** | `<current-branch>` |
> | **Version** | `<version from package.json, or N/A if no package.json>` |
> | **Message** | `<proposed commit message>` |
>
> Confirm commit?

**Rules:**
- Always check `git branch --show-current` and `package.json` version (if present) before
  presenting the confirmation.
- Never skip this block — even if the user has already said "yes" or "commit it". The
  block IS the final gate.
- If the user wants to change the message, branch, or anything else, update and re-present
  the block before committing.

---

## General Safety

- Before any destructive operation, state exactly what will happen and confirm.
- Never delete branches, worktrees, files, or database entries without explicit instruction.
- If unsure which step of the deployment process applies, ask.
- **When in doubt, do less and ask more.**
