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

### Tag Format

The tag format is: **`<emoji> DN <context> · <Stage>`**

Where:
- **`<emoji>`** indicates severity (see Severity Levels below)
- **`DN`** is the short identifier for DeployNOPE
- **`<context>`** is the release version (e.g. `2.10.0`) or branch name (e.g. `fix/login-bug`) for the current work
- **`<Stage>`** is the current workflow step

Example in chat: **`🤓 DN 2.10.0 · Feature`**

### Severity Levels

**Chat + sidecar tags:**

| Emoji | Level | When to use |
|-------|-------|-------------|
| `🤓` | Normal | Branch creation, PRs, merges to release, drift checks, routine actions |
| `⚠️` | Caution | Reset master/staging, force push, merge to staging/production |
| `🚨` | Alert | Rollback, failed gates, blocked actions |

**Sidecar-only indicators** (these appear in the console log but not in chat tags):

| Emoji | Level | When to use |
|-------|-------|-------------|
| `⏳` | Waiting | Human gate — workflow paused for user input |
| `✅` | Complete | A command or significant step finished successfully |

### Stage Labels

Each command and deployment step has its own stage label:

| Context | Stage |
|---|---|
| `/deploynope-new-work` or starting new work | `New Work` |
| `/deploynope-preflight` | `Preflight` |
| `/deploynope-configure` | `Configure` |
| `/deploynope-deploy-status` | `Deploy Status` |
| `/deploynope-verify-rules` | `Verify Rules` |
| `/deploynope-stale-check` | `Stale Check` |
| `/deploynope-release-manifest` | `Release Manifest` |
| `/deploynope-postdeploy` | `Post-Deploy` |
| `/deploynope-rollback` | `Rollback` |
| `/deploynope-console` | `Console` |
| Feature/ticket work (coding, committing) | `Feature` |
| Staging contention check or claiming <staging-branch> | `Staging` |
| Validating on <staging-branch> | `Staging Validation` |
| Resetting <production-branch> / production deployment | `Production` |
| Creating a GitHub Release | `Release` |
| Post-deployment alignment check | `Post-Deploy` |
| General deployment work (no specific step) | `Deploy` |

**Rules:**
- Tag every message — not just the first one — for the duration of the workflow.
- Update the stage label as the workflow progresses through different steps.
- Choose the correct severity emoji for the action (see Severity Levels above).
- If a DeployNOPE command is invoked alongside another framework (e.g. Agile V), tag
  both: **`🤓 DN <context> · <Stage>`** **`[Agile V]`**.
- If an action *should* be governed by DeployNOPE but you are about to skip it, state
  that explicitly rather than proceeding silently.

### Sidecar Console Logging (Step 0)

**This is the first thing you do when any DeployNOPE command activates — before any other
checks, gates, or actions.** Create the log directory/file and write a seed message so
`tail -f` shows immediate output:

```shell
mkdir -p .deploynope && touch .deploynope/console.log
echo "" >> .deploynope/console.log
echo "─── $(date '+%Y-%m-%d %H:%M:%S') ───────────────────────────" >> .deploynope/console.log
echo "[$(date '+%H:%M:%S')] 🤓 DN <context> · <Stage> — <command name> activated" >> .deploynope/console.log
```

From this point, **every tagged message** must also be appended to `.deploynope/console.log`:

```shell
echo "[$(date '+%H:%M:%S')] <emoji> DN <context> · <Stage> — <message>" >> .deploynope/console.log
```

**Rules:**
- Append to the log — never overwrite it.
- One line per message — keep messages concise and actionable.
- Include the severity emoji, DN prefix, context, stage, and a short summary.
- Do not log general conversation or code output — only DeployNOPE guardrail messages.
- The user can run `/deploynope-console` at any time to get the `tail -f` command.
- **Piggyback logging:** Never issue a standalone Bash call just to write to the sidecar
  log. Always chain the `echo >> .deploynope/console.log` onto the Bash command it relates
  to (e.g. `git commit -m "..." && echo "[...] DN ..." >> .deploynope/console.log`). This
  avoids cluttering the user's main chat with extra Bash permission prompts. If a message
  has no associated Bash action (e.g. a pure chat response), skip the sidecar write — the
  user sees it in the main chat already.
- **Human gate logging:** When a DeployNOPE human gate or confirmation prompt is presented
  and the workflow is waiting for user input, log a waiting message to the sidecar. Chain
  this onto the last Bash action before the gate. Format:
  `[HH:MM:SS] ⏳ DN <context> · <Stage> — Waiting for input: <what is being confirmed>`
- **Completion logging:** When a command or significant step finishes successfully, log a
  completion message. Format:
  `[HH:MM:SS] ✅ DN <context> · <Stage> — <what completed>`
- **Error/blocked logging:** When a check fails, a gate blocks progress, or an error is
  encountered, log it immediately. Format:
  `[HH:MM:SS] 🚨 DN <context> · <Stage> — <what failed or was blocked>`

**Sidecar-only emoji reference** (these appear in the console log but not in chat tags):

| Emoji | Meaning | When to use |
|-------|---------|-------------|
| `⏳` | Waiting | Human gate or confirmation prompt — workflow paused for input |
| `✅` | Complete | A command or significant step finished successfully |
| `🚨` | Error/Blocked | A check failed, gate blocked, or error encountered |

**Examples:**
- `[21:30:15] ⏳ DN 2.10.0 · Feature — Waiting for input: commit confirmation`
- `[21:30:20] ✅ DN 2.10.0 · Feature — Committed: feat: add login (a1b2c3d)`
- `[21:31:02] ⏳ DN 2.10.0 · Production — Waiting for input: reset master to staging`
- `[21:31:10] ✅ DN 2.10.0 · Production — Master reset to staging`
- `[21:40:00] 🚨 DN 2.10.0 · New Work — Drift detected: main has commits not in development`
- `[21:40:05] 🚨 DN 2.10.0 · Staging — Staging contention: staging is claimed by another release`

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

**Never suggest pushing directly to `<production-branch>`.** All changes must go through
the full deployment process (<staging-branch> reset → validate → <production-branch> reset) unless
the user explicitly states exceptional circumstances.

When a branch is ready to move forward, always present the deployment process table
with the current position marked, and ask:

> "Shall we start the deployment process?"

Example:

| Step | Action | Status |
|------|--------|--------|
| 1 | Feature branches merged into release branch | ✅ Done |
| 2 | Sync release branch with `<production-branch>` | ✅ Done |
| 3 | Update changelog on release branch (if enabled) | ✅ Done |
| 4 | Confirm release branch is ready | ⬅️ Next |
| 5 | Staging contention check | — |
| 6 | Claim <staging-branch> | — |
| 7 | Reset `<staging-branch>` to match release branch | — |
| 8 | Validate on <staging-branch> | — |
| 9 | Cross-repo version parity check | — |
| 10 | Reset `<production-branch>` to match `<staging-branch>` | — |
| 11 | Confirm CodePipeline healthy | — |
| 12 | Create GitHub Release (both repos) | — |
| 13 | Write release manifest | — |
| 14 | Sync <staging-branch> + <development-branch> with <production-branch> | — |
| 15 | Clear <staging-branch> | — |
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
   and the work cannot follow the correct release flow (`feature → release → <staging-branch> → <production-branch> → <development-branch>`).

   If the user's work is a feature or ticket and no release branch exists yet, prompt them to
   create one first:

   > "There's no active release branch. Would you like to create one (e.g. `release/X.Y.Z`)
   > from `<production-branch>` first? Feature branches should target a release branch, not `<development-branch>`."

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
4. **Resetting `<staging-branch>`** — must pass the <staging-branch> contention check first (see below), then confirm.
5. **Resetting `<production-branch>`** — confirm: "Just to confirm — you want me to reset `<production-branch>` to match `<staging-branch>`?"
6. **Removing worktrees** — list what will be removed and confirm.
7. **After <staging-branch> validation** — wait for explicit "it's validated" sign-off before resetting `<production-branch>`.
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
git log origin/<production-branch>..origin/<staging-branch> --oneline
```

If this shows commits, <staging-branch> has work that hasn't reached production yet.
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

#### Staging contention polling (optional wait)

If Check 1 or Check 2 fails because another release has claimed staging, offer the user
the option to poll until staging is released rather than abandoning the workflow:

> "Staging is currently claimed by `<name>` for `<branch>`.
> Would you like me to poll every minute until staging is released and then automatically
> continue with the deployment?"

If the user accepts:

1. **Set up a recurring poll** using `CronCreate` with a `*/1 * * * *` schedule that runs:

   ```shell
   git fetch origin && git tag -l "staging/active"
   ```

   - If `staging/active` still exists → report "Still waiting — staging claimed by `<name>`."
   - If `staging/active` is gone **and** `git log origin/master..origin/staging --oneline`
     shows no unreleased commits → report **"Staging is now clear!"** and proceed.

2. **Clean up immediately** — as soon as staging is detected as clear (or the user cancels
   the wait), delete the cron job using `CronDelete` with the job ID returned by `CronCreate`.
   Never leave a polling job running after it has served its purpose.

3. **Resume the deployment flow** — once staging is clear and the cron job is cleaned up,
   continue from the "Claiming staging" step below without requiring the user to re-invoke
   the deployment command.

If the user declines, stop the workflow as normal and wait for manual confirmation.

**Check 3: Stale release branch**

Before resetting <staging-branch> to a release branch, verify the release branch contains
**all commits currently on the production branch**. If the production branch has moved
forward since the release branch was created (e.g. another release landed while this
one was in progress), resetting <staging-branch> to the stale branch and then resetting production
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
> These commits would be lost if this release branch goes through <staging-branch> to production.
> You must merge `<production-branch>` into `<release-branch>` first:
>
> ```shell
> git checkout <release-branch>
> git merge origin/<production-branch>
> ```
>
> Resolve any conflicts, then re-run the <staging-branch> reset.

**[HUMAN GATE]** — Do not proceed until the merge is complete and the user has confirmed.

All three checks must pass before claiming staging.

### Claiming staging

When both checks pass and the user has confirmed:

```shell
git tag -a staging/active -m "Claimed by <name> for <branch> on <date>" origin/<staging-branch>
git push origin <staging-branch>/active
```

Prompt the user to notify the team in Slack that <staging-branch> has been claimed and for which branch.

### Clearing staging

After <production-branch> has been reset and the deployment is confirmed healthy:

```shell
git tag -d staging/active
git push origin :staging/active
```

Prompt the user to notify the team in Slack that <staging-branch> is now clear and available.

> **Do not clear <staging-branch> until <production-branch> has been reset and deployment is confirmed.**
> The claim persists from the moment <staging-branch> is taken until the work is live in production.

---

## Resetting `<production-branch>` — Branch Protection Toggle

`<production-branch>` has GitHub branch protection enabled with force-pushes **disabled by default**.
When the deployment process reaches the <production-branch> reset step, Claude must temporarily
enable force-pushes, perform the reset, and immediately re-disable them.

### ⚠️ Worktree Safety Check

**Before resetting `<production-branch>`, verify you are in the main repository clone — not a worktree.**

```shell
git rev-parse --git-dir
```

- If the output is `.git` — you are in the main clone. Safe to proceed.
- If the output contains `/worktrees/` — you are in a worktree. **STOP.**

**Do not run the <production-branch> reset from a worktree.** Running `git checkout <production-branch>` inside
a worktree will fail if `<production-branch>` is already checked out in the main clone (`fatal:
'<production-branch>' is already checked out at ...`). Even if it didn't fail, resetting `<production-branch>`
from a worktree risks operating on the wrong working directory.

If you are in a worktree, switch to the main repository clone first:

> "I'm currently in a worktree. The <production-branch> reset must be run from the main repository
> clone at `<path>`. Please switch to that directory, or confirm I should proceed
> from there."

**[HUMAN GATE]** — Wait for confirmation before continuing.

### Procedure

**[HUMAN GATE]** — Confirm with the user before starting: "Ready to reset `<production-branch>` to
match `<staging-branch>`. This will temporarily enable force-push on `<production-branch>`, perform the reset,
and immediately re-lock it. Proceed?"

**Step 1: Enable force-push**

```shell
gh api repos/{owner}/{repo}/branches/<production-branch>/protection -X PUT --input - <<'EOF'
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

**Step 2: Reset `<production-branch>`**

```shell
git checkout <production-branch>
git reset --hard <staging-branch>
git push --force-with-lease origin <production-branch>
```

**Step 3: Re-lock <production-branch> (immediately)**

```shell
gh api repos/{owner}/{repo}/branches/<production-branch>/protection -X PUT --input - <<'EOF'
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

> **⚠️ If the reset fails (Step 2), still run Step 3 immediately** to re-lock `<production-branch>`.
> Never leave <production-branch> unprotected. If Step 3 also fails, warn the user immediately
> so they can manually re-enable protection in GitHub settings.

The `{owner}/{repo}` placeholders should be replaced with your actual repository names
(e.g. `my-org/backend` and `my-org/frontend`).

---

## Git & Branching Rules

- **Never push without permission.**
- **Never reset `<production-branch>` without completing the <staging-branch> process first.**
- **All changes reach `<production-branch>` via a controlled reset from `<staging-branch>`.** No direct pushes, no PRs to `<production-branch>`.
- **`<production-branch>` is protected.** Force-pushes are disabled by default and only temporarily enabled during the controlled reset (see above).
- **Always ask what branch to branch off of** before creating a new branch.
- **Always ask for the branch name** — never invent one.
- **Always use `--force-with-lease`** instead of `--force`.
- **Always run the <staging-branch> contention check** before resetting `<staging-branch>`.
- **All work types follow the same process** — feature releases, hotfixes, and chore/config changes all go through <staging-branch> → <production-branch> reset. No shortcuts.
- Branches are created off `<production-branch>` unless explicitly told otherwise.

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

1. **`<production-branch>` vs `<staging-branch>`** — commits on `<production-branch>` not in `<staging-branch>`?
2. **`<production-branch>` vs `<development-branch>`** — commits on `<production-branch>` not in `<development-branch>`?

If discrepancies are found, warn the user:

> "Warning: `<production-branch>` has commits not in `<development-branch>` (or `<staging-branch>`). A previous release
> may not have completed the full deployment process. Please resolve this before starting
> a new feature branch."

Do not proceed until the user has acknowledged the warning.

---

## Deployment Timing

**Do not initiate any deployment step after 2:00 PM.** This includes:
- Resetting `<staging-branch>`
- Resetting `<production-branch>`
- Creating a GitHub Release

If attempted after 2:00 PM, warn the user:

> "Warning: it is after 2:00 PM. Deployments outside the safe window increase risk
> during peak traffic hours. Do you want to proceed?"

Wait for explicit written confirmation before continuing.

---

## Deployment Process

All work types follow the same <staging-branch> → <production-branch> reset process.

### Feature Release

1. Feature ticket branches → release branch (e.g. `6.51.0`) via PR
2. Sync release branch with `<production-branch>` (`git merge <production-branch>`)
3. **[CHANGELOG]** Update changelog on the release branch (if enabled in config — see Changelog section below)
4. **[HUMAN GATE]** Confirm release branch is ready
5. **[STAGING CHECK]** Run <staging-branch> contention check (unreleased commits + active claim + stale branch)
6. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
7. Reset `<staging-branch>` to match the release branch: `git reset --hard <release-branch>`
8. **[HUMAN GATE]** Validate on <staging-branch> — wait for explicit "it's validated" sign-off
9. **[CROSS-REPO CHECK]** Confirm frontend/backend version parity (see Cross-Repo Rules)
10. **[HUMAN GATE]** Confirm before resetting `<production-branch>` — CodePipeline deploys automatically
11. Reset `<production-branch>` to match `<staging-branch>`: `git reset --hard <staging-branch>`
12. **Deploy backend first** — confirm CodePipeline healthy before resetting frontend `<production-branch>`
13. Create GitHub Release on **both** repos
14. **[RELEASE MANIFEST]** Write release manifest to `releases/<version>.json`, commit and push to `<production-branch>`
15. **[BRANCH SYNC]** Sync `<staging-branch>` and `<development-branch>` with `<production-branch>` (to pick up manifest commit) — fast-forward or merge `<production-branch>` into both, then push
16. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
17. Write Confluence release notes
18. **[POST-DEPLOY]** Automatically run `/deploynope-postdeploy` checks — do not wait for the user to invoke it

### Hotfix

1. Branch `6.XX.Y` from `<production-branch>`
2. **[CHANGELOG]** Update changelog on the hotfix branch (if enabled in config)
3. **[STAGING CHECK]** Run <staging-branch> contention check (unreleased commits + active claim + stale branch)
4. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
5. Reset `<staging-branch>` to match hotfix branch
6. **[HUMAN GATE]** Validate on staging
7. **[CROSS-REPO CHECK]** Confirm frontend/backend version parity
8. Reset `<production-branch>` to match `<staging-branch>`
9. **Deploy backend first** — confirm CodePipeline healthy before resetting frontend `<production-branch>`
10. Create GitHub Release on both repos
11. **[RELEASE MANIFEST]** Write release manifest, commit and push to `<production-branch>`
12. **[BRANCH SYNC]** Sync `<staging-branch>` and `<development-branch>` with `<production-branch>`, then push
13. Notify in-flight feature branches to pull from `<development-branch>`
14. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
15. Write Confluence release notes
16. **[POST-DEPLOY]** Automatically run `/deploynope-postdeploy` checks

### Chore / Config

1. Branch from `<production-branch>` (e.g. `chore/claude-config`)
2. Do the work, commit, and push
3. **[CHANGELOG]** Update changelog on the chore branch (if enabled in config)
4. **[STAGING CHECK]** Run <staging-branch> contention check (unreleased commits + active claim + stale branch)
5. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
6. Reset `<staging-branch>` to match chore branch
7. **[HUMAN GATE]** Validate on staging
8. Reset `<production-branch>` to match `<staging-branch>`
9. Confirm deployment is healthy
10. **[RELEASE MANIFEST]** Write release manifest (if version bump involved), commit and push to `<production-branch>`
11. **[BRANCH SYNC]** Sync `<staging-branch>` and `<development-branch>` with `<production-branch>`, then push
12. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack
13. **[POST-DEPLOY]** Automatically run `/deploynope-postdeploy` checks

---

## Cross-Repo Rules

**Every code review and deployment task must always consider both repos together.**
Never review or deploy either repo in isolation.

### Version Parity

Frontend and backend must **always be on the same version number** in production,
even if one has no code changes.

Before any `<production-branch>` reset:
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

If `changelog.enabled` is `true` in `.deploynope.json`, update the changelog file
for each release. If `changelog.enabled` is `false` or the `changelog` key is
missing from the config, skip this step entirely.

**This step is mandatory when enabled** — do not skip it or defer it.

The changelog is written **on the release/hotfix/chore branch, before the staging
reset**. This means the changelog entry goes through <staging-branch> like any other code
change, and there is no need for a separate post-deploy commit to `<production-branch>` for
the changelog. The only post-deploy commit to `<production-branch>` should be the release manifest
(which requires the final deployment SHA).

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
git log origin/<production-branch> --oneline -20
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

#### Step 7: Commit to the release branch

```shell
git add <changelog.filePath>
git commit -m "docs: update changelog for <version>"
```

This commit is made **on the release/hotfix/chore branch** before the <staging-branch> reset.
The changelog goes through <staging-branch> like any other change.

**[HUMAN GATE]** — Ask before pushing: "Shall I push the changelog update to the release branch?"

```shell
git push origin <release-branch>
```

---

## Merge Conflict Resolution

- **Always ask which side to prefer** before resolving — never assume.
- When a release branch conflicts with `<staging-branch>` or `<production-branch>`, prefer the release branch
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
git log origin/<production-branch>..origin/<staging-branch> --oneline
git log origin/<staging-branch>..origin/<production-branch> --oneline
git log origin/<production-branch>..origin/<development-branch> --oneline
git log origin/<development-branch>..origin/<production-branch> --oneline

# 2. Version on each branch
for branch in origin/<production-branch> origin/<staging-branch> origin/<development-branch>; do
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
| `<production-branch>` = `<staging-branch>` | ✅ / ❌ | Identical / X commits apart |
| `<production-branch>` = `<development-branch>` | ✅ / ❌ | Identical / X commits apart |
| Version: `<production-branch>` / `<staging-branch>` / `<development-branch>` | ✅ / ❌ | All `<version>` / Mismatch |
| Staging claim | ✅ Clear / ⚠️ Active | Tag details if active |
| Latest GitHub Release | ✅ / ❌ | `<tag>` matches / Behind |
| Open PRs | ℹ️ | X open — flag any targeting key branches |

#### Frontend

| Check | Status | Detail |
|-------|--------|--------|
| `<production-branch>` = `<staging-branch>` | ✅ / ❌ | Identical / X commits apart |
| `<production-branch>` = `<development-branch>` | ✅ / ❌ | Identical / X commits apart |
| Version: `<production-branch>` / `<staging-branch>` / `<development-branch>` | ✅ / ❌ | All `<version>` / Mismatch |
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

After the release manifest is committed and pushed to `<production-branch>`, **`<staging-branch>` and
`<development-branch>` must be synced with `<production-branch>`** before clearing the <staging-branch> claim.
This ensures all three branches include the manifest commit.

**Why this exists:** Without this step, `<production-branch>` ends up ahead of `<staging-branch>` and
`<development-branch>` by the manifest commit. This causes branch drift that accumulates
across releases and was the root cause of repeated post-deploy failures.

The changelog no longer causes drift because it is written on the release branch
before the <staging-branch> reset — it goes through <staging-branch> like any other code change.

### Procedure

```shell
# Sync staging
git checkout <staging-branch>
git merge origin/<production-branch> --no-edit
git push origin <staging-branch>

# Sync development
git checkout <development-branch>
git merge origin/<production-branch> --no-edit
git push origin <development-branch>
```

If either merge is a fast-forward, no merge commit is created — this is ideal.

**This step is mandatory.** Do not clear the <staging-branch> claim until both branches are
synced. Do not skip this step even if the manifest is the only new commit.

---

## Automatic Post-Deploy

At the end of every deployment — after clearing <staging-branch> — **automatically run the
post-deploy checks** (the same checks from `/deploynope-postdeploy`). Do not wait
for the user to invoke `/deploynope-postdeploy` manually.

Display the full post-deploy results table and verdict. If any items are flagged,
present them immediately so they can be addressed before the user moves on.

**Why this exists:** When post-deploy is a separate manual step, it gets forgotten
or deferred, and issues (missing manifests, <staging-branch> still claimed, branch drift)
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

> **`<emoji> DN <context> · <Stage>`**
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

> **`<emoji> DN <context> · <Stage>`**
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

**Before any push to the production branch** (`<production-branch>` from `.deploynope.json`), run this check:

### Step 1: Detect if this is a push to production

If the current branch IS the production branch, this guard applies. If pushing to any
other branch (feature, release, hotfix, chore), skip this guard.

### Step 2: Check for deployment infrastructure

```shell
git branch -r | grep -E "origin/(<staging-branch>|<development-branch>)$" || echo "NONE FOUND"
```

### Step 3a: If <staging-branch> branch exists

**STOP.** Direct pushes to the production branch are not allowed when a <staging-branch> branch
exists. All changes must go through the <staging-branch> → production reset process.

> **❌ BLOCKED — Direct push to production**
>
> This repository has a <staging-branch> branch. All changes must go through the full deployment
> process (<staging-branch> reset → validate → production reset). Direct pushes to `<production-branch>`
> are not permitted.
>
> To proceed, use `/deploynope-deploy` and follow the <staging-branch> → production process.

Do not proceed. Do not offer to override. The <staging-branch> process exists for a reason.

### Step 3b: If NO <staging-branch> branch exists

The repository does not have the branch infrastructure for the full deployment process.
**Warn the user and offer to set it up** before allowing the push:

> **⚠️ WARNING — No <staging-branch> branch detected**
>
> This repository does not have a `<staging-branch>` branch. Without `<staging-branch>`, there is no
> validation step between your code and production. DeployNOPE's full deployment
> process (`<staging-branch>` → validate → production reset) cannot be followed.
>
> Would you like to:
> 1. **Set up deployment infrastructure now** — I'll create `<staging-branch>` and `<development-branch>`
>    branches from the current production branch, so future deployments can follow the
>    full process.
> 2. **Push directly this time** — proceed with the push, understanding that no `<staging-branch>`
>    validation is happening. _(Not recommended for production applications.)_
> 3. **Cancel** — do not push.

**[HUMAN GATE]** — wait for the user to choose before proceeding.

If the user chooses option 1, create the branches:

```shell
git branch <staging-branch> origin/<production-branch>
git push origin <staging-branch>
git branch <development-branch> origin/<production-branch>
git push origin <development-branch>
```

Then advise:
> "`<staging-branch>` and `<development-branch>` branches created. From now on, all deployments should go
> through the full <staging-branch> → production process. Run `/deploynope-configure` to confirm
> your branch names are set correctly."

If the user chooses option 2, allow the push but add a **`⚠️ NO STAGING`** warning row
to the push confirmation block.

---

## General Safety

- Before any destructive operation, state exactly what will happen and confirm.
- Never delete branches, worktrees, files, or database entries without explicit instruction.
- If unsure which step of the deployment process applies, ask.
- **When in doubt, do less and ask more.**
