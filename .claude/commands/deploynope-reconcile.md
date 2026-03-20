# /deploynope-reconcile — Reconcile a Manual Release

> Audits the current repo state after someone has done a release **outside** of DeployNOPE.
> Detects what was done, identifies what was missed, and offers to bring the release into
> full alignment with the DeployNOPE process.
>
> Use this when a teammate has manually pushed, merged, or deployed without running
> DeployNOPE — for example, they've reset `<production-branch>` and `<staging-branch>` but haven't created
> a GitHub Release, written a manifest, or checked branch alignment.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE <context> · Reconcile`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Configuration

Check for `.deploynope.json` in the current working directory. If it exists, read it and
use its values in place of all placeholders throughout this command (see `/deploynope-configure`
for the full mapping). If it does not exist, use the placeholder names as-is and suggest:

> "Tip: run `/deploynope-configure` to set up your repo names, branch names, and Confluence
> details so they're filled in automatically."

---

## Arguments

This command accepts an optional version argument:

```
/deploynope-reconcile 6.51.1
```

If a version is provided, use it as the target version for the audit. If no version is
provided, auto-detect it (see Step 1 below).

---

## Instructions

When this command is run, perform the following steps in order.

---

### Step 1: Detect What Happened

Gather forensic data to understand the current state and infer what release (if any)
was performed manually.

```shell
git fetch origin --quiet

# Recent commits on production — who pushed what, and when?
git log origin/<production-branch> --oneline -20 --format='%h %ai %an | %s'

# Recent commits on staging — does it match production?
git log origin/<staging-branch> --oneline -10 --format='%h %ai %an | %s'

# Recent commits on development — was it updated?
git log origin/<development-branch> --oneline -10 --format='%h %ai %an | %s'

# Version-patterned branches (release/hotfix candidates)
git branch -r | grep -E 'origin/[0-9]+\.[0-9]+\.[0-9]+'

# Existing tags and releases
git tag -l 'v*' --sort=-v:refname | head -10
gh release list --limit 10

# Version in package.json on production
git show origin/<production-branch>:package.json 2>/dev/null | grep '"version"' | head -1
```

From this data, determine:

1. **The version that was released** — from `package.json` on `<production-branch>`, or from the
   version argument if provided.
2. **The release branch** — look for a remote branch matching the version pattern.
3. **Who did it** — the author of the most recent commits on `<production-branch>`.
4. **When it happened** — the timestamp of the `<production-branch>` HEAD commit.
5. **The release type** — infer from the version bump:
   - Patch bump (e.g. 6.51.0 → 6.51.1) = hotfix
   - Minor bump (e.g. 6.51.0 → 6.52.0) = feature release
   - Major bump = major release
   - No bump or unclear = ask the user

Present your findings before proceeding:

> **Detected release:** `<version>` (type: `<feature/hotfix/chore>`)
> **Release branch:** `<branch>` (or "none found")
> **Deployed by:** `<name>` on `<date>`
> **Previous version:** `<previous version>`
>
> Does this look right? If not, please correct me before I continue.

**[HUMAN GATE]** — Wait for the user to confirm the detection is correct before
running the audit checks.

---

### Step 2: Run the Alignment Audit

Once the version is confirmed, run the following checks. These mirror the DeployNOPE
post-deployment checklist but are designed to detect gaps in a manual release.

---

#### Check 1: Branch Alignment

```shell
git log origin/<staging-branch>..origin/<production-branch> --oneline
git log origin/<production-branch>..origin/<staging-branch> --oneline
git log origin/<development-branch>..origin/<production-branch> --oneline
git log origin/<production-branch>..origin/<development-branch> --oneline
git log origin/<development-branch>..origin/<staging-branch> --oneline
git log origin/<staging-branch>..origin/<development-branch> --oneline
```

Check all three pairs. For each pair, report the direction and count of diverging commits.
The expected state after a complete deployment is that all three branches are identical
(or `<production-branch>` may be 1 commit ahead if the release manifest was committed after the reset).

---

#### Check 2: GitHub Release Exists

```shell
gh release view "v<version>" --json tagName,name,createdAt,body 2>/dev/null
```

Check whether a GitHub Release exists for the detected version. If both repos are
configured and accessible, check both.

---

#### Check 3: Release Manifest Exists

```shell
ls releases/<version>.json 2>/dev/null
```

Check whether a manifest file exists for this version.

---

#### Check 4: Branch Protection State

```shell
gh api repos/{owner}/{repo}/branches/<production-branch>/protection --jq '.allow_force_pushes.enabled' 2>/dev/null
ls -la .deploynope-protection-unlocked 2>/dev/null
```

Force-push should be `false`. If it is `true`, branch protection was left unlocked.
Also check for the `.deploynope-protection-unlocked` state file.

---

#### Check 5: Staging Claim Cleared

```shell
git tag -l "staging/active"
git tag -n1 "staging/active"
```

The `staging/active` tag should not exist after a completed deployment.

---

#### Check 6: Changelog Updated

If `changelog.enabled` is `true` in `.deploynope.json`:

```shell
head -30 <changelog.filePath>
```

Check whether the changelog has an entry for the detected version.

---

#### Check 7: Version Parity (Cross-Repo)

If both repos are configured in `.deploynope.json`:

```shell
# Check version on production in the other repo
# (Use gh api or clone as appropriate)
gh api repos/{owner}/{other-repo}/contents/package.json?ref=<production-branch> --jq '.content' | base64 -d | grep '"version"'
```

Compare the production version across both repos. They must match.

---

#### Check 8: Release Branch Cleanup

```shell
git branch -r | grep -E "origin/<version>"
```

Check whether the release branch still exists on the remote. After a completed
deployment, the release branch may remain (this is acceptable) but should be flagged
if it has diverged from `<production-branch>`.

If it still exists, check for divergence:

```shell
git log origin/<production-branch>..origin/<version> --oneline
git log origin/<version>..origin/<production-branch> --oneline
```

---

### Step 3: Display the Audit Results

Present the results in this format:

**`🤓 DeployNOPE <version> · Reconcile`**

**Release Reconciliation Audit**
_Repo: `<owner>/<repo>` | Date: `<today>` | Detected version: `<version>`_
_Deployed by: `<name>` on `<date>` | Type: `<feature/hotfix/chore>`_

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | Branch alignment | ✅ / ⚠️ / ❌ | All aligned / Drift details |
| 2 | GitHub Release | ✅ / ❌ | `v<version>` exists / No release found |
| 3 | Release manifest | ✅ / ❌ | `releases/<version>.json` exists / Not found |
| 4 | Branch protection | ✅ / ❌ | Force-push disabled / Still unlocked |
| 5 | Staging cleared | ✅ / ❌ | No active claim / Claim still present |
| 6 | Changelog updated | ✅ / ⏭️ / ❌ | Entry for `<version>` / Not enabled / Not updated |
| 7 | Version parity | ✅ / ⏭️ / ❌ | Both repos at `<version>` / Single repo / Mismatch |
| 8 | Release branch state | ✅ / ⚠️ | Clean / Diverged from `<production-branch>` |

---

### Step 4: Offer Remediation

For each failing check, offer a specific remediation action. Group all offers together
and let the user choose which ones to proceed with.

> **Remediation available for X items:**
>
> 1. ❌ **GitHub Release missing** — Would you like me to create a GitHub Release for
>    `v<version>`? I'll generate release notes from the commits between `v<previous-version>`
>    and `v<version>`.
>
> 2. ❌ **Release manifest missing** — Would you like me to write `releases/<version>.json`?
>    I can gather the SHAs, branch info, and release URLs automatically.
>
> 3. ❌ **`<development-branch>` not updated** — `<production-branch>` has X commits not in `<development-branch>`.
>    Would you like me to reconcile these branches? I'll analyse the divergence and
>    recommend a strategy (merge or cherry-pick) based on your config and the branch state.
>
> 4. ❌ **Branch protection unlocked** — Force-push is still enabled on `<production-branch>`.
>    Would you like me to re-lock it?
>
> 5. ❌ **Staging claim still active** — The `staging/active` tag is still present.
>    Would you like me to clear it?
>
> 6. ❌ **Changelog not updated** — No entry for `<version>` found in `<changelog.filePath>`.
>    Would you like me to generate a changelog entry from the commit history?
>
> Which of these would you like me to do? (e.g. "all", "1, 2, 3", or "none")

**[HUMAN GATE]** — Wait for the user to select which remediations to perform.

---

### Step 5: Execute Remediations

For each remediation the user approves, follow the corresponding DeployNOPE procedure:

#### GitHub Release

Generate release notes from commits between the previous version tag and the current
version on `<production-branch>`:

```shell
git log v<previous-version>..origin/<production-branch> --oneline --no-merges
```

Create the release:

```shell
gh release create "v<version>" --target <production-branch> --title "v<version>" --notes "<generated notes>"
```

**[HUMAN GATE]** — Show the draft release notes and ask for confirmation before creating.

#### Release Manifest

Follow the procedure in `/deploynope-release-manifest`. Gather all data from git and
GitHub, present it for review, then write and commit the file.

**[HUMAN GATE]** — Show the manifest content and ask before committing.

#### Branch Alignment (`<development-branch>`)

Branch alignment requires choosing a **reconciliation strategy**. Read the configured
preference from `.deploynope.json` (`reconciliation.preferredStrategy`). Then analyse
the divergence to make a recommendation.

**Step A — Analyse the divergence:**

```shell
# Count commits each way
git log origin/<development-branch>..origin/<production-branch> --oneline
git log origin/<production-branch>..origin/<development-branch> --oneline

# Check for merge commits (indicates shared history vs rebased/squashed history)
git log origin/<development-branch>..origin/<production-branch> --merges --oneline

# Check if branches share a recent common ancestor
git merge-base origin/<production-branch> origin/<development-branch>
```

Use these heuristics to form a recommendation:

| Signal | Recommends | Reason |
|--------|------------|--------|
| `<development-branch>` has 0 commits ahead of `<production-branch>` | **Merge** | Clean fast-forward possible; no risk of lost work |
| `<production-branch>` is many commits ahead (>10) | **Merge** | Too many commits to cherry-pick safely — high risk of missing one |
| `<production-branch>` is 1–3 commits ahead, `<development-branch>` is 0 ahead | **Either** | Both are safe; cherry-pick gives a cleaner history |
| Both branches have diverged (commits on both sides) | **Merge** | Cherry-picking from diverged branches is error-prone and can silently drop changes |
| History was squash-merged or rebased (no shared merge commits) | **Merge** | Cherry-pick relies on matching commit SHAs — squash/rebase breaks this |
| Prior cherry-pick reconciliation lost commits (known incident) | **Merge** | Safety over cleanliness — merge guarantees completeness |

**Step B — Present the recommendation:**

If `reconciliation.preferredStrategy` is `"ask"`, or if `reconciliation.allowOverride`
is `true`:

> **Reconciliation Strategy**
>
> The branches have diverged as follows:
> - `<production-branch>` has **X commits** not in `<development-branch>`
> - `<development-branch>` has **Y commits** not in `<production-branch>`
>
> **Recommendation: `<merge or cherry-pick>`**
> _Reason: `<explanation based on the heuristics above>`_
>
> | Strategy | Pros | Cons |
> |----------|------|------|
> | **Merge** | All commits included, no risk of missed work | Merge commit in history, may bring unwanted changes |
> | **Cherry-pick** | Selective, cleaner history | Must identify every commit individually — risk of missing work |
>
> Which strategy would you like to use?
> 1. **Merge** `<production-branch>` into `<development-branch>` ← `<recommended or not>`
> 2. **Cherry-pick** specific commits from `<production-branch>` into `<development-branch>` ← `<recommended or not>`

If the configured preference is `"merge"` or `"cherry-pick"` and `allowOverride` is
`false`, skip the prompt and proceed with the configured strategy. Still show the
recommendation analysis so the user can see *why* that strategy is being used.

**[HUMAN GATE]** — Wait for the user to choose a strategy before proceeding.

**Step C — Execute the chosen strategy:**

**If Merge:**

```shell
git checkout <development-branch>
git pull origin <development-branch>
git merge origin/<production-branch> --no-edit
```

**[HUMAN GATE]** — Ask before pushing.

```shell
git push origin <development-branch>
```

**If Cherry-pick:**

First, list the commits that need to be cherry-picked:

```shell
git log origin/<development-branch>..origin/<production-branch> --oneline --reverse
```

Present the list and ask the user to confirm which commits to include:

> "The following commits on `<production-branch>` are not in `<development-branch>`:
>
> ```
> <commit list>
> ```
>
> **Include all of these?** If not, tell me which to skip.
>
> ⚠️ **Warning:** cherry-picking is selective by nature. Any commit not included will
> be permanently absent from `<development-branch>`. If you are unsure whether a commit
> is needed, include it — it is safer to include too many than too few."

**[HUMAN GATE]** — Wait for confirmation of the commit list.

```shell
git checkout <development-branch>
git pull origin <development-branch>
git cherry-pick <sha1> <sha2> ... --no-edit
```

If conflicts arise during cherry-pick, stop and report:

> "Cherry-pick conflict on commit `<sha>` (`<message>`). This is a risk of cherry-pick
> reconciliation — the commit depends on context that doesn't exist in `<development-branch>`.
>
> Options:
> 1. Resolve the conflict manually (I'll show you the conflicting files)
> 2. Abort cherry-pick and switch to **merge** instead (recommended if multiple conflicts)
> 3. Skip this commit"

**[HUMAN GATE]** — Ask before pushing.

```shell
git push origin <development-branch>
```

After pushing, run a verification diff to confirm alignment:

```shell
git log origin/<development-branch>..origin/<production-branch> --oneline
```

If commits remain, warn:

> "⚠️ After cherry-pick, `<production-branch>` still has **N commits** not in
> `<development-branch>`. This is expected if you chose to skip some, but verify this
> is intentional."

#### Branch Protection Re-Lock

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

Also remove the state file if present:

```shell
rm -f .deploynope-protection-unlocked
```

#### Staging Claim Clear

```shell
git tag -d staging/active
git push origin :staging/active
```

#### Changelog Update

Follow the changelog procedure from `/deploynope-deploy`. Auto-populate from commit
history if `changelog.autoPopulate` is true, using the format specified in
`.deploynope.json`.

**[HUMAN GATE]** — Show the changelog entry and ask before committing.

---

### Step 6: Post-Remediation Summary

After all selected remediations are complete, re-run the audit checks (Step 2) and
display the updated results table. This confirms everything is now aligned.

If all checks pass:

> **✅ RECONCILIATION COMPLETE**
>
> Version `<version>` is now fully aligned with the DeployNOPE process.
> All deployment artifacts and branch states match what a managed deployment would produce.

If items remain:

> **⚠️ RECONCILIATION PARTIAL**
>
> The following items were not remediated (user chose to skip):
> - `<item>`
>
> Run `/deploynope-reconcile <version>` again when ready to address these.

---

## Edge Cases

### No version detected

If auto-detection cannot determine the version (e.g. no recent version-patterned commits
on `<production-branch>`), ask the user:

> "I couldn't auto-detect a recent release version. What version should I audit?
> (e.g. `6.51.1`)"

### Multiple releases detected

If it looks like multiple versions were released since the last GitHub Release, flag this:

> "It looks like multiple versions may have been released since the last tracked release
> (`v<last-release>`). The following version-patterned branches have been merged into
> `<production-branch>`:
> - `<version-1>`
> - `<version-2>`
>
> Which version would you like to reconcile first?"

Run the audit for one version at a time.

### Release already fully aligned

If all checks pass with no remediation needed:

> **✅ ALREADY ALIGNED**
>
> Version `<version>` was deployed manually but all DeployNOPE artifacts and branch states
> are in order. No action needed.

### Worktree safety

Before any remediation that modifies branches (merges, pushes, commits), check that
you are not in a detached worktree that could cause issues:

```shell
git rev-parse --git-dir
```

If the result is not `.git`, warn the user and suggest switching to the main working
directory for remediation actions.

---

## When to Run This

- A teammate has done a manual release or deployment without using DeployNOPE.
- You suspect a deployment was partially completed (e.g. branches updated but no GitHub Release).
- After an incident or ad-hoc production fix where the normal process was bypassed.
- As a periodic audit to catch any releases that slipped through without full documentation.

Suggest pairing this with `/deploynope-stale-check` for a complete pipeline health picture.
