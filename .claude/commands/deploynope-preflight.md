# /deploynope-preflight — Am I Clear to Deploy?

> Pre-deployment readiness check. Run this before starting any deployment work.
> It answers one question: "Is it safe to start deploying right now?"
>
> This is a read-only check. It does not modify any state.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE @ Preflight`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Configuration

Check for `.deploynope.json` in the current working directory. If it exists, read it and
use its values in place of all placeholders throughout this command (see `/deploynope-configure`
for the full mapping). If it does not exist, use the placeholder names as-is and suggest:

> "Tip: run `/deploynope-configure` to set up your repo names, branch names, and Confluence
> details so they're filled in automatically."

---

## Instructions

When this command is run, perform **all** of the following checks, then display the
results table and a clear go / no-go verdict.

---

## Checks to Run

### 1. Deployment Rules Loaded

Verify that the deployment ruleset from `/deploynope-deploy` has been loaded in this
conversation. If not, this is a blocker — the rules must be loaded before deploying.

### 2. Uncommitted or Unpushed Work

```shell
git status --short
git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null
```

Flag any uncommitted changes or unpushed commits on the current branch.

### 3. Branch Up to Date with Production

```shell
git fetch origin --quiet
git log $(git branch --show-current)..origin/master --oneline
```

If the current branch is behind `master`, it needs to be synced before deploying.

### 4. Staging Contention

```shell
git log origin/master..origin/staging --oneline
git tag -l "staging/active"
git tag -n1 "staging/active"
```

If staging has unreleased commits or an active claim tag, staging is not available.

### 4b. Stale Release Branch

```shell
git log <current-branch>..origin/master --oneline
```

If the production branch has commits not in the current release branch, the branch is
stale. Deploying it would rewind production, erasing newer work. This is a **blocker** —
the release branch must be merged with the production branch before proceeding.

### 5. Deployment Timing

Check the current time against the configured deployment cutoff (default: 2:00 PM).

If it is after the cutoff, flag it as a warning (not a blocker — the user can override).

### 6. Cross-Repo Version Parity

Check `package.json` version on the current branch. If the other repo is accessible,
compare versions. If not accessible, note it as unchecked.

### 7. Open PRs

```shell
gh pr list --state open
```

List any open PRs — particularly those targeting `staging` or `master`, which could
indicate in-flight work.

### 8. Branch Drift

```shell
git log origin/master..origin/staging --oneline
git log origin/staging..origin/master --oneline
git log origin/master..origin/development --oneline
git log origin/development..origin/master --oneline
```

If `master`, `staging`, and `development` are not aligned, a previous deployment may
not have completed fully. Flag it.

---

## Output Format

Display the results in exactly this format:

**Preflight Check**
_Date: `<today>` | Time: `<current time>` | Branch: `<current-branch>`_

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | Deployment rules loaded | ✅ / ❌ | Loaded / Not loaded — run `/deploynope-deploy` first |
| 2 | Working tree clean | ✅ / ⚠️ | Clean / X uncommitted changes, Y unpushed commits |
| 3 | Branch synced with production | ✅ / ⚠️ | Up to date / X commits behind `master` |
| 4 | Staging available | ✅ / ❌ | Clear / Claimed by `<name>` or X unreleased commits |
| 4b | Release branch current | ✅ / ❌ | Contains all production commits / Stale — X commits behind production |
| 5 | Deployment window | ✅ / ⚠️ | Within window / After cutoff (`<time>`) |
| 6 | Version parity | ✅ / ⚠️ / — | Matching / Mismatch / Other repo not checked |
| 7 | Open PRs | ✅ / ℹ️ | None / X open — list any targeting key branches |
| 8 | Branch drift | ✅ / ⚠️ | All aligned / Drift detected — details |

---

## Verdict

After the table, display one of:

### All clear

> **✅ CLEAR TO DEPLOY**
>
> All preflight checks passed. Run `/deploynope-deploy` to load the deployment ruleset
> (if not already loaded), then proceed with the deployment process.

### Blockers found

> **❌ NOT CLEAR TO DEPLOY**
>
> The following must be resolved before deploying:
> - `<blocker 1>`
> - `<blocker 2>`
>
> Resolve these issues, then run `/deploynope-preflight` again.

### Warnings only (no blockers)

> **⚠️ CLEAR TO DEPLOY WITH WARNINGS**
>
> No blockers found, but note the following:
> - `<warning 1>`
> - `<warning 2>`
>
> You can proceed, but address these if possible. Run `/deploynope-deploy` to load
> the deployment ruleset (if not already loaded).

---

## Blocker vs Warning

| Severity | Meaning | Examples |
|----------|---------|----------|
| ❌ Blocker | Cannot deploy until resolved | Rules not loaded, staging claimed, staging has unreleased commits, release branch stale (behind production) |
| ⚠️ Warning | Can proceed but should be aware | After cutoff time, uncommitted changes, branch drift, other repo not checked |
| ✅ Pass | No issues | — |
