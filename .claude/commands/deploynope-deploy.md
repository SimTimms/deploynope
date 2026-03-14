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

**Every response** produced while DeployNOPE rules are active must begin with a contextual
stage tag so the user can immediately see which framework is driving decisions **and what
stage of the process they are in**.

The tag format is: **`🤓 DeployNOPE @ <Stage>`**

Each command and deployment step has its own stage label:

| Context | Tag |
|---|---|
| `/deploynope-new-work` or starting new work | `🤓 DeployNOPE @ New Work` |
| `/deploynope-preflight` | `🤓 DeployNOPE @ Preflight` |
| `/deploynope-configure` | `🤓 DeployNOPE @ Configure` |
| `/deploynope-deploy-status` | `🤓 DeployNOPE @ Deploy Status` |
| `/deploynope-verify-rules` | `🤓 DeployNOPE @ Verify Rules` |
| `/deploynope-stale-check` | `🤓 DeployNOPE @ Stale Check` |
| `/deploynope-release-manifest` | `🤓 DeployNOPE @ Release Manifest` |
| `/deploynope-postdeploy` | `🤓 DeployNOPE @ Post-Deploy` |
| `/deploynope-rollback` | `🤓 DeployNOPE @ Rollback` |
| Feature/ticket work (coding, committing) | `🤓 DeployNOPE @ Feature` |
| Staging contention check or claiming staging | `🤓 DeployNOPE @ Staging` |
| Validating on staging | `🤓 DeployNOPE @ Staging Validation` |
| Resetting master / production deployment | `🤓 DeployNOPE @ Production` |
| Creating a GitHub Release | `🤓 DeployNOPE @ Release` |
| Post-deployment alignment check | `🤓 DeployNOPE @ Post-Deploy` |
| General deployment work (no specific step) | `🤓 DeployNOPE @ Deploy` |

**Rules:**
- Tag every message — not just the first one — for the duration of the workflow.
- Update the stage label as the workflow progresses through different steps.
- If a DeployNOPE command is invoked alongside another framework (e.g. Agile V), tag
  both: **`🤓 DeployNOPE @ <Stage>`** **`[Agile V]`**.
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
| 12 | Write release manifest | — |
| 13 | Update changelog (if enabled) | — |
| 14 | Sync staging + development with master | — |
| 15 | Clear staging | — |
| 16 | Write Confluence release notes | — |
| 17 | Post-deploy checks (automatic) | — |

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
   > "Based on the deployment process, I'd recommend branching from `master` because [reason].
   > Would you like to use that, or a different base?
   > 1. `master` ← recommended
   > 2. An existing release branch (e.g. `release/1.2.0`) — for ticket/feature work feeding into a release
   > 3. Other — please specify"

   **Warning:** Do **not** offer `development` as a base branch. The `development` branch is
   only updated by merging the release branch into it **after** production deployment. Branching
   from `development` creates a mismatch: the PR hook will block PRs targeting `development`,
   and the work cannot follow the correct release flow (`feature → release → staging → master → development`).

   If the user's work is a feature or ticket and no release branch exists yet, prompt them to
   create one first:

   > "There's no active release branch. Would you like to create one (e.g. `release/X.Y.Z`)
   > from `master` first? Feature branches should target a release branch, not `development`."

4. **If creating a release branch, run the release version check** (see below).

5. **Run the branch drift check** before creating the branch (see below).

---

## Release Version Check

**Before creating any release branch** (a branch named with a version pattern like `X.Y.Z`),
fetch from the remote and check all existing versions to determine the next available version.

```shell
git fetch origin
# Check existing version tags
git tag -l 'v*' --sort=-v:refname
# Check existing version-patterned branches
git branch -r | grep -E 'origin/[0-9]+\.[0-9]+\.[0-9]+'
# Check existing GitHub releases
gh release list --limit 10
```

**Rules:**
- The new release branch version **must be higher** than any existing tag, release, or
  version-patterned branch.
- If the user provides a version number, validate it against the remote before using it.
  If it conflicts with an existing version, warn the user and suggest the next available version.
- If the user provides only a major version (e.g. "1"), look up the latest `1.x.y` release
  and suggest the next minor bump (e.g. if `1.3.0` exists, suggest `1.4.0`).
- **Never create a release branch without running this check first.** This prevents
  version collisions with already-released or in-progress versions.

> "I've checked the remote — the latest version is `<version>`. The next available
> release branch would be `<next-version>`. Shall I use that?"

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

**Check 3: Stale release branch**

Before resetting staging to a release branch, verify the release branch contains
**all commits currently on the production branch**. If the production branch has moved
forward since the release branch was created (e.g. another release landed while this
one was in progress), resetting staging to the stale branch and then resetting production
to match would **rewind production**, erasing the newer work.

```shell
git fetch origin
git log <release-branch>..origin/<production-branch> --oneline
```

If this shows any commits, the release branch is stale. **Do not reset staging.**

> **❌ BLOCKED — Stale release branch**
>
> `<production-branch>` has commits not in `<release-branch>`:
>
> ```
> <commit list>
> ```
>
> These commits would be lost if this release branch goes through staging to production.
> You must merge `<production-branch>` into `<release-branch>` first:
>
> ```shell
> git checkout <release-branch>
> git merge origin/<production-branch>
> ```
>
> Resolve any conflicts, then re-run the staging reset.

**[HUMAN GATE]** — Do not proceed until the merge is complete and the user has confirmed.

All three checks must pass before claiming staging.

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

## PR Target Validation

**Before creating or suggesting a PR**, fetch from the remote and verify the target branch
has not already been released:

```shell
git fetch origin
git tag -l 'v*' --sort=-v:refname
gh release list --limit 10
```

If the target branch is a release branch (version-patterned like `X.Y.Z`) and a matching
tag or GitHub Release already exists, that release branch has already been deployed.
**Do not create a PR targeting it.**

> "The release branch `<version>` has already been deployed (tag `v<version>` exists).
> A PR targeting this branch would add changes to an already-released version.
> Would you like to create a new release branch (`<next-version>`) and target that instead?"

**[HUMAN GATE]** — wait for the user to confirm the new target before creating the PR.

This check also applies when suggesting a PR target after pushing a feature branch.
Never assume the current release branch is still active — always verify against the remote.

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
4. **[STAGING CHECK]** Run staging contention check (unreleased commits + active claim + stale branch)
5. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
6. Reset `staging` to match the release branch: `git reset --hard <release-branch>`
7. **[HUMAN GATE]** Validate on staging — wait for explicit "it's validated" sign-off
8. **[CROSS-REPO CHECK]** Confirm frontend/backend version parity (see Cross-Repo Rules)
9. **[HUMAN GATE]** Confirm before resetting `master` — CodePipeline deploys automatically
10. Reset `master` to match `staging`: `git reset --hard staging`
11. **Deploy backend first** — confirm CodePipeline healthy before resetting frontend `master`
12. Create GitHub Release on **both** repos
13. **[RELEASE MANIFEST]** Write release manifest to `releases/<version>.json`, commit and push to `master`
14. **[CHANGELOG]** Update changelog (if enabled in config — see Changelog section below), commit and push to `master`
15. **[BRANCH SYNC]** Sync `staging` and `development` with `master` (to pick up manifest + changelog commits) — fast-forward or merge `master` into both, then push
16. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
17. Write Confluence release notes
18. **[POST-DEPLOY]** Automatically run `/deploynope-postdeploy` checks — do not wait for the user to invoke it

### Hotfix

1. Branch `6.XX.Y` from `master`
2. **[STAGING CHECK]** Run staging contention check (unreleased commits + active claim + stale branch)
3. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
4. Reset `staging` to match hotfix branch
5. **[HUMAN GATE]** Validate on staging
6. **[CROSS-REPO CHECK]** Confirm frontend/backend version parity
7. Reset `master` to match `staging`
8. **Deploy backend first** — confirm CodePipeline healthy before resetting frontend `master`
9. Create GitHub Release on both repos
10. **[RELEASE MANIFEST]** Write release manifest, commit and push to `master`
11. **[CHANGELOG]** Update changelog (if enabled in config), commit and push to `master`
12. **[BRANCH SYNC]** Sync `staging` and `development` with `master`, then push
13. Notify in-flight feature branches to pull from `development`
14. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
15. Write Confluence release notes
16. **[POST-DEPLOY]** Automatically run `/deploynope-postdeploy` checks

### Chore / Config

1. Branch from `master` (e.g. `chore/claude-config`)
2. Do the work, commit, and push
3. **[STAGING CHECK]** Run staging contention check (unreleased commits + active claim + stale branch)
4. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
5. Reset `staging` to match chore branch
6. **[HUMAN GATE]** Validate on staging
7. Reset `master` to match `staging`
8. Confirm deployment is healthy
9. **[RELEASE MANIFEST]** Write release manifest (if version bump involved), commit and push to `master`
10. **[CHANGELOG]** Update changelog (if enabled in config), commit and push to `master`
11. **[BRANCH SYNC]** Sync `staging` and `development` with `master`, then push
12. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
13. **[POST-DEPLOY]** Automatically run `/deploynope-postdeploy` checks

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

## Changelog

If `changelog.enabled` is `true` in `.deploynope.json`, update the changelog file after
each production deployment. If `changelog.enabled` is `false` or the `changelog` key is
missing from the config, skip this step entirely.

**This step is mandatory when enabled** — do not skip it or defer it. It runs
automatically as part of the deployment flow, immediately after the release manifest
is written and before the branch sync step.

The changelog is updated **after creating the GitHub Release and writing the manifest**
and **before syncing branches**. This ensures the changelog commit is included in the
branch sync and all three branches end up aligned.

### Procedure

#### Step 1: Determine the previous version

Check the most recent entry in the changelog file, or use the `previousVersion` from the
release manifest if available.

#### Step 2: Gather changes

If `changelog.autoPopulate` is `true`, scan the commit history between the previous
version and the current version:

```shell
git log v<previous-version>..v<current-version> --oneline --no-merges
```

If no tags exist yet, fall back to:

```shell
git log origin/master --oneline -20
```

Group the commits according to the configured format (see Step 3).

If `changelog.autoPopulate` is `false`, present an empty template for the user to fill in.

#### Step 3: Format the entry

Format the changelog entry according to `changelog.format`:

**`keepachangelog` format:**

```markdown
## [<version>] - <YYYY-MM-DD>

### Added
- <new features>

### Changed
- <changes to existing functionality>

### Fixed
- <bug fixes>

### Removed
- <removed features>
```

Omit any section that has no entries. When auto-populating, categorise commits by their
prefix (`feat:` → Added, `fix:` → Fixed, `chore:`/`refactor:` → Changed, etc.). Commits
without a recognised prefix go under Changed.

**`simple` format:**

```markdown
## <version> (<YYYY-MM-DD>)

- <change description>
- <change description>
```

**`conventional` format:**

```markdown
## <version> (<YYYY-MM-DD>)

### Features
- <feat: commits>

### Bug Fixes
- <fix: commits>

### Chores
- <chore: commits>

### Other
- <uncategorised commits>
```

Omit any section that has no entries.

#### Step 4: Add links (if enabled)

If `changelog.includeLinks` is `true`, append a compare link at the bottom of the entry:

```markdown
[<version>]: https://github.com/<owner>/<repo>/compare/v<previous-version>...v<version>
```

Also convert any PR references (`#123`) or issue references to full links.

#### Step 5: Present for review

**[HUMAN GATE]** — Show the drafted changelog entry to the user before writing it:

> "Here is the changelog entry for version `<version>`. Please review and let me know
> if you'd like to make any changes before I write it to `<filePath>`."

Display the full formatted entry. Wait for approval or edits.

#### Step 6: Write to file

Prepend the new entry to the changelog file at the configured `changelog.filePath`
(default: `CHANGELOG.md`).

- If the file does not exist, create it with a header:
  ```markdown
  # Changelog

  All notable changes to this project will be documented in this file.

  ```
  Then append the entry.

- If the file exists, insert the new entry after the header and before the previous
  version's entry.

#### Step 7: Commit

```shell
git add <changelog.filePath>
git commit -m "docs: update changelog for <version>"
```

This commit goes directly to `master` alongside the release manifest — it is a
post-deployment record, not a code change.

**[HUMAN GATE]** — Ask before pushing: "Shall I push the changelog update to `master`?"

```shell
git push origin master
```

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

## Post-Manifest Branch Sync

After the release manifest (and changelog, if enabled) are committed and pushed to
`master`, **`staging` and `development` must be synced with `master`** before clearing
the staging claim. This ensures all three branches include the manifest and changelog
commits.

**Why this exists:** Without this step, `master` ends up ahead of `staging` and
`development` by the manifest/changelog commits. This causes branch drift that
accumulates across releases and was the root cause of repeated post-deploy failures.

### Procedure

```shell
# Sync staging
git checkout staging
git merge origin/master --no-edit
git push origin staging

# Sync development
git checkout development
git merge origin/master --no-edit
git push origin development
```

If either merge is a fast-forward, no merge commit is created — this is ideal.

**This step is mandatory.** Do not clear the staging claim until both branches are
synced. Do not skip this step even if the manifest is the only new commit.

---

## Automatic Post-Deploy

At the end of every deployment — after clearing staging — **automatically run the
post-deploy checks** (the same checks from `/deploynope-postdeploy`). Do not wait
for the user to invoke `/deploynope-postdeploy` manually.

Display the full post-deploy results table and verdict. If any items are flagged,
present them immediately so they can be addressed before the user moves on.

**Why this exists:** When post-deploy is a separate manual step, it gets forgotten
or deferred, and issues (missing manifests, staging still claimed, branch drift)
accumulate silently.

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

> **`🤓 DeployNOPE @ <Stage>`**
>
> | | |
> |---|---|
> | **Branch** | `<current-branch>` |
> | **Version** | `<version from package.json, or N/A if no package.json>` |
> | **Message** | `<proposed commit message>` |
>
> Confirm commit?

Use the stage label that matches the current workflow context (e.g. `Feature`, `Staging`, `Production`).

**Rules:**
- Always check `git branch --show-current` and `package.json` version (if present) before
  presenting the confirmation.
- Never skip this block — even if the user has already said "yes" or "commit it". The
  block IS the final gate.
- If the user wants to change the message, branch, or anything else, update and re-present
  the block before committing.
- **Commit prefixes:** If `commitPrefixes` is `true` in `.deploynope.json`, every commit
  message **must** start with a prefix followed by a colon and space (e.g. `feat: add login`).
  Choose the prefix based on the change:
  - `feat` — new functionality
  - `fix` — bug fix
  - `chore` — maintenance, deps, config
  - `refactor` — restructuring, no behaviour change
  - `docs` — documentation only
  - `test` — adding or updating tests
  If the user provides a message without a prefix, prepend the appropriate one.
  If `commitPrefixes` is `false` or not set, do not add prefixes.

---

## Push Confirmation Format

**No push may be executed without showing this confirmation block first** — regardless
of whether you or the user initiates the push. This includes when the user says "yes",
"push it", "go ahead", or any other approval. The confirmation block is the last step
before `git push` runs.

**Flow:**
1. User approves or requests a push (or you propose one).
2. **Run the Production Branch Guard** (see below) before anything else.
3. Gather the current branch, remote, version, and list of commits to be pushed.
4. Display the confirmation block below.
5. Wait for the user to approve or request changes.
6. Only after explicit approval, run `git push`.

**Confirmation block format:**

> **`🤓 DeployNOPE @ <Stage>`**
>
> | | |
> |---|---|
> | **Branch** | `<current-branch>` → `origin/<branch>` |
> | **Version** | `<version from package.json, or N/A if no package.json>` |
> | **Commits** | `<count>` commit(s) to push |
>
> | SHA | Message |
> |-----|---------|
> | `<short-sha>` | `<commit message first line>` |
> | `<short-sha>` | `<commit message first line>` |
>
> Confirm push?

Use the stage label that matches the current workflow context (e.g. `Feature`, `Staging`, `Production`).

**Rules:**
- Always run `git log origin/<branch>..HEAD --oneline` to get the exact commits that
  will be pushed.
- Always check `git branch --show-current` and `package.json` version (if present).
- Never skip this block — even if the user has already said "push it". The block IS
  the final gate.
- If the push is a force-push (`--force-with-lease`), add a **`⚠️ FORCE PUSH`** warning
  row to the table.
- If the user wants to change anything, update and re-present the block before pushing.

---

## Production Branch Guard

**Before any push to the production branch** (`master`, `main`, or whatever is configured
in `.deploynope.json` as `productionBranch`), run this check:

### Step 1: Detect if this is a push to production

If the current branch IS the production branch, this guard applies. If pushing to any
other branch (feature, release, hotfix, chore), skip this guard.

### Step 2: Check for deployment infrastructure

```shell
git branch -r | grep -E 'origin/(staging|develop|development)' || echo "NONE FOUND"
```

### Step 3a: If staging branch exists

**STOP.** Direct pushes to the production branch are not allowed when a staging branch
exists. All changes must go through the staging → production reset process.

> **❌ BLOCKED — Direct push to production**
>
> This repository has a staging branch. All changes must go through the full deployment
> process (staging reset → validate → production reset). Direct pushes to `<production-branch>`
> are not permitted.
>
> To proceed, use `/deploynope-deploy` and follow the staging → production process.

Do not proceed. Do not offer to override. The staging process exists for a reason.

### Step 3b: If NO staging branch exists

The repository does not have the branch infrastructure for the full deployment process.
**Warn the user and offer to set it up** before allowing the push:

> **⚠️ WARNING — No staging branch detected**
>
> This repository does not have a `staging` branch. Without staging, there is no
> validation step between your code and production. DeployNOPE's full deployment
> process (staging → validate → production reset) cannot be followed.
>
> Would you like to:
> 1. **Set up deployment infrastructure now** — I'll create `staging` and `development`
>    branches from the current production branch, so future deployments can follow the
>    full process.
> 2. **Push directly this time** — proceed with the push, understanding that no staging
>    validation is happening. _(Not recommended for production applications.)_
> 3. **Cancel** — do not push.

**[HUMAN GATE]** — wait for the user to choose before proceeding.

If the user chooses option 1, create the branches:

```shell
git branch staging origin/<production-branch>
git push origin staging
git branch development origin/<production-branch>
git push origin development
```

Then advise:
> "Staging and development branches created. From now on, all deployments should go
> through the full staging → production process. Run `/deploynope-configure` to confirm
> your branch names are set correctly."

If the user chooses option 2, allow the push but add a **`⚠️ NO STAGING`** warning row
to the push confirmation block.

---

## General Safety

- Before any destructive operation, state exactly what will happen and confirm.
- Never delete branches, worktrees, files, or database entries without explicit instruction.
- If unsure which step of the deployment process applies, ask.
- **When in doubt, do less and ask more.**
