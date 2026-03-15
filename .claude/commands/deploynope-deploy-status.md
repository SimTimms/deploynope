# /deploynope-deploy-status — Where Are We in the Deployment Process?

When this command is run, perform the following checks and then display the
deployment status table. Always use the exact same format and emoji set.

> **Framework Visibility:** Tag every response with **`🤓 DN <context> · Deploy Status`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Checks to Run

Gather the following information before building the table:

### Git State
```shell
# Current branch
git branch --show-current

# Unpushed local commits
git log origin/<branch>..HEAD --oneline

# Staged but uncommitted changes
git diff --cached --name-only

# Unstaged changes
git status --short

# Compare release branch with <production-branch>
git log origin/<production-branch>..<release-branch> --oneline

# Compare <production-branch> with <staging-branch>
git log origin/<staging-branch>..origin/<production-branch> --oneline

# Unreleased commits on <staging-branch> (staging contention check)
git log origin/<production-branch>..origin/<staging-branch> --oneline

# Compare <production-branch> with <development-branch>
git log origin/<development-branch>..origin/<production-branch> --oneline

# Staging claim tag
git tag -l "staging/active"
git tag -n1 "staging/active"

# Open PRs
gh pr list --state open

# Latest tags / GitHub Releases
gh release list --limit 5
```

### Memory & Context
- Check conversation history for any steps already confirmed or completed this session
- Check memory files for any relevant project state
- Note the current version in `package.json`
- Note the current version on the frontend repo if accessible

---

## Status Table Format

Always display the table in exactly this format. Never change the column names,
order, or emoji set. Update only the Status column.

**Emoji key — use these and only these:**

| Emoji | Meaning |
|-------|---------|
| ✅ | Confirmed done |
| ⬅️ | Current / next step |
| ⏳ | In progress |
| ❌ | Blocked or failed |
| ⚠️ | Needs attention before proceeding |
| — | Not started |

---

## Detect Branch Type

Determine which table to display based on the branch:

- **Feature release** — branch name matches a version pattern like `6.XX.0`
- **Hotfix** — branch name matches a patch version like `6.XX.Y` where Y > 0
- **Chore / config** — branch name starts with `chore/`, `fix/`, `ci/`, or is a Jira ticket ID, or does not match a version pattern

All work types follow the same <staging-branch> → <production-branch> reset process.

---

## Feature Release Table

**Deployment Status: `<release-branch>` → production**
_Version: `<version>` | Branch: `<current-branch>` | Date: `<today>`_

| # | Step | Detail | Status |
|---|------|--------|--------|
| 1 | Feature branches merged into release branch | All ticket PRs merged into `<release-branch>` | — |
| 2 | Sync release branch with `<production-branch>` | `git merge <production-branch>` run on release branch | — |
| 3 | Release branch confirmed ready | Human sign-off | — |
| 4 | Staging contention check passed | No unreleased commits on `<staging-branch>`; no `staging/active` tag | — |
| 5 | Staging claimed | `staging/active` tag created; team notified in Slack | — |
| 6 | `<staging-branch>` reset to match release branch | `git reset --hard <release-branch>` | — |
| 7 | Validated on <staging-branch> | Human sign-off: "it's validated" | — |
| 8 | Cross-repo version parity confirmed | Backend and frontend on same version | — |
| 9 | `<production-branch>` reset to match `<staging-branch>` — backend | `git reset --hard <staging-branch>` | — |
| 10 | Backend CodePipeline confirmed healthy | Before frontend proceeds | — |
| 11 | `<production-branch>` reset to match `<staging-branch>` — frontend (if applicable) | `git reset --hard <staging-branch>` | — |
| 12 | GitHub Release created — backend | Tag: `<version>` | — |
| 13 | GitHub Release created — frontend | Tag: `<version>` | — |
| 14 | Release branch merged into `<development-branch>` | Keeps `<development-branch>` aligned | — |
| 15 | Staging cleared | `staging/active` tag removed; team notified in Slack | — |
| 16 | Confluence release notes written | Confluence release notes | — |
| 17 | Smoke test on production | Human sign-off | — |
| 18 | Branch alignment check | All branches aligned across both repos | — |

---

## Hotfix Table

**Deployment Status: `<hotfix-branch>` → production**
_Version: `<version>` | Branch: `<current-branch>` | Date: `<today>`_

| # | Step | Detail | Status |
|---|------|--------|--------|
| 1 | Hotfix branch created from `<production-branch>` | Branch: `<hotfix-branch>` | — |
| 2 | Staging contention check passed | No unreleased commits on `<staging-branch>`; no `staging/active` tag | — |
| 3 | Staging claimed | `staging/active` tag created; team notified in Slack | — |
| 4 | `<staging-branch>` reset to match hotfix branch | `git reset --hard <hotfix-branch>` | — |
| 5 | Validated on <staging-branch> | Human sign-off: "it's validated" | — |
| 6 | Cross-repo version parity confirmed | Backend and frontend on same version | — |
| 7 | `<production-branch>` reset to match `<staging-branch>` — backend | `git reset --hard <staging-branch>` | — |
| 8 | Backend CodePipeline confirmed healthy | Before frontend proceeds | — |
| 9 | `<production-branch>` reset to match `<staging-branch>` — frontend (if applicable) | `git reset --hard <staging-branch>` | — |
| 10 | GitHub Release created — backend | Tag: `<version>` | — |
| 11 | GitHub Release created — frontend | Tag: `<version>` | — |
| 12 | Hotfix branch merged into `<development-branch>` | Keeps `<development-branch>` aligned | — |
| 13 | In-flight feature branches notified | Pull from `<development-branch>` | — |
| 14 | Staging cleared | `staging/active` tag removed; team notified in Slack | — |
| 15 | Confluence release notes written | Confluence release notes | — |
| 16 | Smoke test on production | Human sign-off | — |
| 17 | Branch alignment check | All branches aligned across both repos | — |

---

## Chore / Config Table

**Deployment Status: `<chore-branch>` → production**
_Branch: `<current-branch>` | Date: `<today>`_

| # | Step | Detail | Status |
|---|------|--------|--------|
| 1 | Changes committed and pushed | All work committed and pushed to origin | — |
| 2 | Staging contention check passed | No unreleased commits on `<staging-branch>`; no `staging/active` tag | — |
| 3 | Staging claimed | `staging/active` tag created; team notified in Slack | — |
| 4 | `<staging-branch>` reset to match chore branch | `git reset --hard <chore-branch>` | — |
| 5 | Validated on <staging-branch> | Human sign-off: "it's validated" | — |
| 6 | `<production-branch>` reset to match `<staging-branch>` | `git reset --hard <staging-branch>` | — |
| 7 | Deployment confirmed healthy | CodePipeline triggered and confirmed | — |
| 8 | `<production-branch>` merged into `<development-branch>` | Keeps `<development-branch>` aligned | — |
| 9 | Staging cleared | `staging/active` tag removed; team notified in Slack | — |
| 10 | Branch alignment check | All branches aligned across both repos | — |

---

After displaying the table, state:
- What was determined from git checks
- Staging contention status (unreleased commits? active claim tag?)
- Any warnings (drift, uncommitted changes, open PRs that may be affected)
- The recommended next step
