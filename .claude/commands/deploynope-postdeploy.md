# /deploynope-postdeploy — Did I Close Everything Out?

> Post-deployment completion check. Run this after a deployment to make sure nothing
> was missed. It answers one question: "Am I actually done?"
>
> This is a read-only check. It does not modify any state.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE <context> · Post-Deploy`** while this command
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
results table and a clear done / not-done verdict.

---

## Checks to Run

### 1. Master Reset Completed

```shell
git fetch origin --quiet
git log origin/<staging-branch>..origin/<production-branch> --oneline
git log origin/<production-branch>..origin/<staging-branch> --oneline
```

`<production-branch>` and `<staging-branch>` should be identical (or `<production-branch>` may be 1 commit ahead if the
release manifest was committed). If `<staging-branch>` is ahead of `<production-branch>`, the reset has not
been completed.

### 2. GitHub Releases Created

```shell
gh release list --limit 3
```

Check that a GitHub Release exists for the version that was just deployed. If both repos
are accessible, check both.

### 3. Release Manifest Written

```shell
ls releases/*.json 2>/dev/null | tail -1
```

Check that a release manifest file exists for the deployed version in `releases/`.

### 4. Release Branch Merged into Development

```shell
git log origin/<development-branch>..origin/<production-branch> --oneline
```

If `<production-branch>` has commits not in `<development-branch>`, the release branch has not been merged
back. This is required to keep `<development-branch>` aligned.

### 5. Branch Protection Re-Enabled

```shell
gh api repos/{owner}/{repo}/branches/<production-branch>/protection --jq '.allow_force_pushes.enabled'
ls -la .deploynope-protection-unlocked 2>/dev/null
```

Force-push must be `false`. If it is `true`, branch protection was not re-locked after
the <production-branch> reset. Also check for the `.deploynope-protection-unlocked` state file — if
it exists, the protection toggle hook did not clean up properly. Remove the state file
after confirming protection is re-locked.

### 6. Staging Cleared

```shell
git tag -l "staging/active"
```

The `staging/active` tag should not exist. If it does, <staging-branch> has not been released
back to the team.

### 7. Confluence Release Notes

Check conversation history for whether Confluence release notes were written during this
session. If Confluence is configured (`.deploynope.json` has a non-null `confluence.spaceKey`),
this should have been done.

If Confluence is not configured, mark as skipped.

### 8. Branch Alignment

```shell
git log origin/<production-branch>..origin/<staging-branch> --oneline
git log origin/<staging-branch>..origin/<production-branch> --oneline
git log origin/<production-branch>..origin/<development-branch> --oneline
git log origin/<development-branch>..origin/<production-branch> --oneline
```

All three branches (`<production-branch>`, `<staging-branch>`, `<development-branch>`) should be aligned. Small
discrepancies (e.g. the release manifest commit) are acceptable — flag anything larger.

### 9. Changelog Updated

If `changelog.enabled` is `true` in `.deploynope.json`:

```shell
head -20 <changelog.filePath>
```

Check that the changelog file exists at the configured path and that the latest entry
matches the deployed version.

If changelog is not enabled (or the `changelog` key is missing from config), mark as skipped.

### 10. Production Smoke Test

Check conversation history for whether the user confirmed a production smoke test
during this session. This is a human responsibility — just check if it was acknowledged.

---

## Output Format

Display the results in exactly this format:

**Post-Deployment Check**
_Date: `<today>` | Version: `<version>` | Type: `<feature/hotfix/chore>`_

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | Master reset completed | ✅ / ❌ | `<production-branch>` and `<staging-branch>` aligned / `<staging-branch>` is X commits ahead |
| 2 | GitHub Releases created | ✅ / ❌ | Release `<version>` found / No release found |
| 3 | Release manifest written | ✅ / ❌ | `releases/<version>.json` exists / Not found |
| 4 | Merged into <development-branch> | ✅ / ❌ | `<development-branch>` aligned / X commits behind `<production-branch>` |
| 5 | Branch protection re-enabled | ✅ / ❌ | Force-push disabled / Force-push still enabled or state file present |
| 6 | Staging cleared | ✅ / ❌ | No active claim / `staging/active` tag still present |
| 7 | Confluence release notes | ✅ / ⏭️ / ❌ | Written / Skipped (not configured) / Not written |
| 8 | Branch alignment | ✅ / ⚠️ | All aligned / Drift detected — details |
| 9 | Changelog updated | ✅ / ⏭️ / ❌ | Updated for `<version>` / Skipped (not enabled) / Not updated |
| 10 | Production smoke test | ✅ / ⚠️ | Confirmed by user / Not confirmed this session |

---

## Verdict

After the table, display one of:

### All done

> **✅ DEPLOYMENT COMPLETE**
>
> All post-deployment checks passed. Version `<version>` is live and all cleanup
> steps are done. Staging is clear for the next deployment.

### Outstanding items

> **❌ DEPLOYMENT NOT COMPLETE**
>
> The following items still need attention:
> - `<item 1>`
> - `<item 2>`
>
> Complete these, then run `/deploynope-postdeploy` again to confirm.

### Minor items only

> **⚠️ DEPLOYMENT COMPLETE WITH NOTES**
>
> The deployment is functionally complete, but note the following:
> - `<note 1>`
> - `<note 2>`
>
> These are non-blocking but should be addressed when convenient.

---

## Outstanding vs Note

| Severity | Meaning | Examples |
|----------|---------|----------|
| ❌ Outstanding | Deployment is not finished | Master not reset, branch protection still unlocked, <staging-branch> not cleared |
| ⚠️ Note | Done but worth flagging | Smoke test not confirmed, minor branch drift, Confluence not configured |
| ✅ Pass | Completed | — |
| ⏭️ Skipped | Not applicable | Confluence not configured, changelog not enabled, single-repo setup |
