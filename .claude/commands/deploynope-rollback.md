# /deploynope-rollback — Roll Back a Production Deployment

> Loaded via `/deploynope-rollback`. Use this when a production deployment needs to be reverted
> to the previous release. Supports two modes: Standard and Emergency.
>
> - **Backend:** `{owner}/{backend-repo}`
> - **Frontend:** `{owner}/{frontend-repo}`
>
> **Framework Visibility:** Tag every response with **`🚨 DeployNOPE <context> · Rollback`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Configuration

Check for `.deploynope.json` in the current working directory. If it exists, read it and
use its values in place of all placeholders throughout this command (see `/deploynope-configure`
for the full mapping). If it does not exist, use the placeholder names as-is and suggest:

> "Tip: run `/deploynope-configure` to set up your repo names, branch names, and Confluence
> details so they're filled in automatically."

---

## Incomplete Picture Warning

If planning or executing a rollback without access to any of the following,
**stop immediately and warn the user** before continuing:

- The corresponding frontend or backend repository
- AWS CodePipeline status
- The current and previous GitHub Release tags on both repos
- Any external system relevant to the task (Jira tickets, incident channels, etc.)

State clearly what is missing and what impact it may have before proceeding.

---

## Choose Rollback Mode

Ask the user before proceeding:

> "Which rollback mode do you need?
> 1. **Standard Rollback** — goes through <staging-branch> validation (same safety gates as a forward deployment)
> 2. **Emergency Rollback** — skips <staging-branch> validation for critical production outages (extra human gates apply)
>
> If production is down or severely degraded, choose Emergency."

**[HUMAN GATE]** — wait for the user to select a mode before continuing.

---

## Identify Rollback Target

### Step 1: Find the current and previous releases

```shell
# Backend
gh release list --repo {owner}/{backend-repo} --limit 5

# Frontend
gh release list --repo {owner}/{frontend-repo} --limit 5
```

Identify:
- **Current release** — the most recent GitHub Release tag (this is what is being rolled back)
- **Rollback target** — the release immediately before the current one

### Step 2: Check for a release manifest

```shell
# Check if a release manifest exists for the current version
cat releases/<current-version>.json 2>/dev/null
```

If a manifest file exists, use it to determine:
- Which repos were included in the deployment
- What the previous version was for each repo
- Any deployment-specific metadata

If no manifest file exists, that is fine — determine the rollback target from the
GitHub Release tags identified above. The release manifest is being introduced
alongside rollback and may not exist for older releases.

### Step 3: Determine cross-repo scope

**[HUMAN GATE]** — Present the findings and confirm scope:

> "Current release: `<current-version>`
> Rollback target: `<previous-version>`
>
> Repos deployed in the current release:
> - Backend: `<yes/no>` (tag found: `<tag>`)
> - Frontend: `<yes/no>` (tag found: `<tag>`)
>
> Which repos need to be rolled back?
> 1. Both backend and frontend
> 2. Backend only
> 3. Frontend only"

Wait for explicit confirmation of the rollback scope.

---

## Deployment Timing

**Standard rollback:** Do not initiate after 2:00 PM. If attempted, warn:

> "Warning: it is after 2:00 PM. Rollbacks outside the safe window increase risk
> during peak traffic hours. Do you want to proceed, or
> switch to Emergency mode?"

**[HUMAN GATE]** — wait for written confirmation.

**Emergency rollback:** Timing restrictions do not apply. Production outages take
priority over deployment windows.

---

## Frontend Rollback — Cache Busting

> **This section applies whenever the frontend is in rollback scope.**

The frontend **cannot** be rolled back by simply resetting to a previous version tag.
The frontend uses version-based cache busting — if the current production version is
`6.44.2` and you reset to `6.44.1`, browsers will see this as a version regression
and will **not** download the older assets.

To work around this, a frontend rollback must **increment the version number forward**
while resetting the code to the previous known-good state. The browser sees a new,
higher version and fetches the assets.

### Procedure

Example: `6.44.2` is broken, `6.44.1` was the last good version.

1. **Create a new PATCH branch from the last known-good tag:**
   ```shell
   git checkout -b 6.44.3 6.44.1
   ```

2. **Bump the version in `package.json`:**
   ```shell
   npm version 6.44.3 --no-git-tag-version
   ```

3. **Regenerate the lock file:**
   ```shell
   npm install --legacy-peer-deps
   ```

4. **Commit the version bump:**
   ```shell
   git add package.json package-lock.json
   git commit -m "Rollback to 6.44.1 code — version bump for cache busting"
   ```

5. **Push the branch:**
   ```shell
   git push origin 6.44.3
   ```

This cache-bust branch then replaces `<rollback-target-tag>` in the Standard or
Emergency process steps below. Instead of resetting `<staging-branch>`/`<production-branch>` to the old tag,
reset them to the cache-bust branch.

> **Key point:** The backend can reset directly to the previous tag. The frontend
> must always go through the cache-bust branch. When both repos are in scope,
> the backend uses the tag and the frontend uses the cache-bust branch.

---

## Standard Rollback Process

Standard rollback follows the same <staging-branch> -> validate -> <production-branch> reset flow as a
forward deployment. The only difference is that the target is the previous release
tag (backend) or the cache-bust branch (frontend) instead of a release branch.

### Pre-Flight Checks

```shell
# Pull latest
git fetch origin

# Check for other Claude instances
ps aux | grep -i claude | grep -v grep

# Current state of <production-branch>
git log origin/<production-branch> --oneline -5

# Current state of <staging-branch>
git log origin/<staging-branch> --oneline -5
```

### Process

1. **[STAGING CHECK]** Run <staging-branch> contention check (unreleased commits + active claim)
2. **[STAGING CLAIM]** Create `staging/active` tag; notify team in Slack
3. If frontend is in scope, **create the cache-bust branch** (see Frontend Rollback — Cache Busting above)
4. Reset `<staging-branch>` to match the rollback target:
   - **Backend:** `git reset --hard <rollback-target-tag>`
   - **Frontend:** `git reset --hard <cache-bust-branch>` (e.g. `6.44.3`)
   ```shell
   git checkout <staging-branch>
   git reset --hard <target>
   git push --force-with-lease origin <staging-branch>
   ```
5. **[HUMAN GATE]** Validate on <staging-branch> — wait for explicit "it's validated" sign-off
6. **[CROSS-REPO CHECK]** Confirm both repos will be on matching versions after rollback
7. **[HUMAN GATE]** Confirm before resetting `<production-branch>`:
   > "Ready to roll back `<production-branch>` from `<current-version>` to `<rollback-target>`.
   > This will temporarily enable force-push on `<production-branch>`, perform the reset, and
   > immediately re-lock it. Proceed?"
8. Reset backend `<production-branch>` using the Branch Protection Toggle procedure (see deploynope-deploy.md):
   - Enable force-push on `<production-branch>`
   - `git reset --hard <rollback-target-tag>`
   - `git push --force-with-lease origin <production-branch>`
   - Re-lock `<production-branch>` immediately (even if the reset fails)
9. **Deploy backend first** — confirm CodePipeline healthy before rolling back frontend
10. If frontend is in scope, repeat the <production-branch> reset on `{owner}/{frontend-repo}`
    using the **cache-bust branch** (not the old tag):
    - `git reset --hard <cache-bust-branch>`
11. Create GitHub Release for the frontend cache-bust version (note in description that
    this is a rollback with version bump for cache busting)
12. Run the Post-Rollback Checklist (see below)
13. **[STAGING CLEAR]** Remove `staging/active` tag; notify team in Slack

---

## Emergency Rollback Process

Emergency rollback skips <staging-branch> validation. Use only when production is down or
severely degraded and the cost of waiting for <staging-branch> validation exceeds the risk
of rolling back without it.

### Extra Safety Gates

Because <staging-branch> validation is skipped, emergency rollback requires additional
human gates to compensate:

- **[HUMAN GATE]** Explicit confirmation that this is a genuine emergency
- **[HUMAN GATE]** Confirmation of the exact rollback target before any reset
- **[HUMAN GATE]** Confirmation before each <production-branch> reset (backend and frontend separately)
- **[HUMAN GATE]** Mandatory post-rollback validation on production

### Pre-Flight

```shell
# Pull latest
git fetch origin

# Confirm current production state
git log origin/<production-branch> --oneline -3

# Confirm rollback target exists
git tag -l "<rollback-target-tag>"
git log <rollback-target-tag> --oneline -3
```

### Process

1. **[HUMAN GATE]** Confirm emergency:
   > "You are requesting an Emergency Rollback. This will skip <staging-branch> validation
   > and reset `<production-branch>` directly to `<rollback-target>`. Please confirm:
   > - This is a genuine production emergency
   > - You accept the risk of deploying without <staging-branch> validation
   >
   > Type 'confirmed' to proceed."

2. **Staging contention bypass:** In emergency mode, <staging-branch> contention checks are
   skipped. However, if the `staging/active` tag exists, warn the user:
   > "Warning: <staging-branch> is currently claimed by another deployment. Emergency rollback
   > will not touch `<staging-branch>`, but be aware that another deployment may be in progress."

   **[HUMAN GATE]** — wait for acknowledgement.

3. If frontend is in scope, **create the cache-bust branch** (see Frontend Rollback —
   Cache Busting above). Even in emergency mode, the frontend cannot skip this step
   because browsers will not fetch assets from an older version number.

4. **[HUMAN GATE]** Confirm the exact rollback target:
   > "About to reset `<production-branch>`:
   > - Backend: tag `<rollback-target>` (`<commit-sha>`)
   > - Frontend: cache-bust branch `<cache-bust-branch>` _(if in scope)_
   >
   > Confirm this is correct."

5. Reset backend `<production-branch>` using the Branch Protection Toggle procedure:
   - Enable force-push on `<production-branch>`
   - `git reset --hard <rollback-target-tag>`
   - `git push --force-with-lease origin <production-branch>`
   - Re-lock `<production-branch>` immediately (even if the reset fails)

6. **[HUMAN GATE]** Confirm CodePipeline triggered and backend is recovering:
   > "Backend `<production-branch>` has been reset. CodePipeline should trigger automatically.
   > Please confirm the backend deployment is progressing before we proceed to
   > the frontend."

7. If frontend is in scope:
   **[HUMAN GATE]** Confirm before resetting frontend `<production-branch>`:
   > "Ready to reset frontend `<production-branch>` to cache-bust branch `<cache-bust-branch>`. Proceed?"

   Reset using the **cache-bust branch** (not the old tag):
   - `git reset --hard <cache-bust-branch>`

   Repeat the Branch Protection Toggle procedure on `{owner}/{frontend-repo}`.

8. If frontend was rolled back, create GitHub Release for the cache-bust version
   (note in description that this is a rollback with version bump for cache busting)

9. Run the Post-Rollback Checklist (see below) — **all items are mandatory in
   emergency mode, especially production validation.**

---

## Post-Rollback Checklist

After the rollback is complete, work through every item:

### 1. CodePipeline Health

```shell
# Check pipeline status (both repos if applicable)
# Prompt user to verify in AWS Console
```

> "Please confirm CodePipeline has completed successfully for:
> - [ ] Backend
> - [ ] Frontend _(if applicable)_"

**[HUMAN GATE]** — wait for confirmation.

### 2. Production Smoke Test

> "Please run a smoke test on production and confirm:
> - [ ] Application loads correctly
> - [ ] Authentication works
> - [ ] Core user flows are functional
> - [ ] The issue that triggered the rollback is resolved _(emergency mode)_"

**[HUMAN GATE]** — wait for explicit sign-off.

### 3. GitHub Release Annotation

Annotate the rolled-back release to indicate it was reverted:

```shell
# Get the current release body and prepend a rollback notice
gh release view <current-version> --repo {owner}/{backend-repo} --json body -q .body
```

Update the release notes:

```shell
gh release edit <current-version> --repo {owner}/{backend-repo} \
  --notes "**Rolled back** on <date> — reverted to \`<rollback-target>\`. Reason: <reason>

---

<original-release-notes>"
```

Repeat for frontend if applicable.

**[HUMAN GATE]** — confirm the annotation text before applying.

### 4. Confluence Incident Note

Write a brief incident note in Confluence:

- **Space:** `{confluence-space-key}`
- **Space ID:** `{confluence-space-id}`
- **Cloud ID:** `{confluence-cloud-id}`
- **Release notes folder ID:** `{confluence-folder-id}`
- **Format:** Date, rolled-back version, rollback target, reason, who performed it,
  whether it was standard or emergency, any follow-up actions

**[HUMAN GATE]** — confirm content with the user before publishing.

### 5. Notify Team

Prompt the user to notify the team:

> "Please notify the team in Slack:
> - What was rolled back (`<current-version>` -> `<rollback-target>`)
> - Standard or Emergency rollback
> - Current production status
> - Any follow-up actions needed"

---

## Rollback Status Table

Display and update this table throughout the rollback process. Use the same emoji
key as `/deploynope-deploy-status`.

**Emoji key — use these and only these:**

| Emoji | Meaning |
|-------|---------|
| ✅ | Confirmed done |
| ⬅️ | Current / next step |
| ⏳ | In progress |
| ❌ | Blocked or failed |
| ⚠️ | Needs attention before proceeding |
| — | Not started |

### Standard Rollback Table

**Rollback Status: `<current-version>` -> `<rollback-target>`**
_Mode: Standard | Repos: `<scope>` | Date: `<today>`_

| # | Step | Detail | Status |
|---|------|--------|--------|
| 1 | Rollback target identified | Current: `<current>`, Target: `<target>` | — |
| 2 | Rollback scope confirmed | Repos: `<backend/frontend/both>` | — |
| 3 | Release manifest checked | `releases/<version>.json` | — |
| 4 | Frontend cache-bust branch created | Branch `<cache-bust>` from `<target>` tag _(if frontend in scope)_ | — |
| 5 | Staging contention check passed | No unreleased commits on staging; no `staging/active` tag | — |
| 6 | Staging claimed | `staging/active` tag created; team notified in Slack | — |
| 7 | `<staging-branch>` reset to rollback target | Backend: tag; Frontend: cache-bust branch | — |
| 8 | Validated on <staging-branch> | Human sign-off: "it's validated" | — |
| 9 | Cross-repo version parity confirmed | Backend and frontend on matching versions | — |
| 10 | `<production-branch>` reset — backend | `git reset --hard <rollback-target>` | — |
| 11 | Backend CodePipeline confirmed healthy | Before frontend proceeds | — |
| 12 | `<production-branch>` reset — frontend (if applicable) | `git reset --hard <cache-bust-branch>` | — |
| 13 | Frontend CodePipeline confirmed healthy | If applicable | — |
| 14 | GitHub Release — frontend cache-bust | Tag: `<cache-bust-version>` _(if applicable)_ | — |
| 15 | Production smoke test passed | Human sign-off | — |
| 16 | GitHub Release annotated — backend | Rollback notice added | — |
| 17 | GitHub Release annotated — frontend | Rollback notice on original release _(if applicable)_ | — |
| 18 | Confluence incident note written | Confluence release notes | — |
| 19 | Team notified in Slack | Rollback complete, production status | — |
| 20 | Staging cleared | `staging/active` tag removed; team notified in Slack | — |

### Emergency Rollback Table

**Rollback Status: `<current-version>` -> `<rollback-target>`**
_Mode: EMERGENCY | Repos: `<scope>` | Date: `<today>`_

| # | Step | Detail | Status |
|---|------|--------|--------|
| 1 | Emergency confirmed | Human confirmed genuine emergency | — |
| 2 | Rollback target identified | Current: `<current>`, Target: `<target>` | — |
| 3 | Rollback scope confirmed | Repos: `<backend/frontend/both>` | — |
| 4 | Release manifest checked | `releases/<version>.json` | — |
| 5 | Frontend cache-bust branch created | Branch `<cache-bust>` from `<target>` tag _(if frontend in scope)_ | — |
| 6 | Staging contention acknowledged | Warned if `staging/active` tag exists | — |
| 7 | Rollback target confirmed | Human confirmed exact tag/branch and commit | — |
| 8 | `<production-branch>` reset — backend | `git reset --hard <rollback-target>` | — |
| 9 | Backend CodePipeline confirmed healthy | Human sign-off | — |
| 10 | `<production-branch>` reset — frontend (if applicable) | `git reset --hard <cache-bust-branch>` | — |
| 11 | Frontend CodePipeline confirmed healthy | If applicable | — |
| 12 | GitHub Release — frontend cache-bust | Tag: `<cache-bust-version>` _(if applicable)_ | — |
| 13 | Production smoke test passed | Human sign-off — mandatory in emergency mode | — |
| 14 | GitHub Release annotated — backend | Rollback notice added | — |
| 15 | GitHub Release annotated — frontend | Rollback notice on original release _(if applicable)_ | — |
| 16 | Confluence incident note written | Confluence release notes | — |
| 17 | Team notified in Slack | Rollback complete, production status | — |

---

## Resetting `<production-branch>` — Branch Protection Toggle

Follow the exact same procedure as defined in deploynope-deploy.md. For reference:

1. **[HUMAN GATE]** — Confirm before starting
2. Enable force-push on `<production-branch>` via `gh api`
3. `git reset --hard <rollback-target-tag>` and `git push --force-with-lease origin <production-branch>`
4. Re-lock `<production-branch>` immediately — even if the reset fails

The `{owner}/{repo}` placeholders:
- Backend: `{owner}/{backend-repo}`
- Frontend: `{owner}/{frontend-repo}`

> **Never leave <production-branch> unprotected.** If re-locking fails, warn the user immediately
> so they can manually re-enable protection in GitHub settings.

---

## Cross-Repo Rules

All cross-repo rules from deploy.md apply during rollback:

- Both repos must be on matching version numbers after rollback
- If both repos were deployed in the release being rolled back, both must be rolled back
  (unless the user explicitly confirms only one needs reverting)
- Backend is always rolled back first; confirm CodePipeline healthy before proceeding
  to frontend
- If access to either repo is missing, stop and flag it

---

## General Safety

- **Never push without permission.**
- **Never force-push `<production-branch>` without toggling branch protection** (same procedure as deploynope-deploy.md).
- **Always use `--force-with-lease`** instead of `--force`.
- Before any destructive operation, state exactly what will happen and confirm.
- **When in doubt, do less and ask more.**
