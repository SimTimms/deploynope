# /deploynope-stale-check — Stale Work & Pipeline Health Check

> Identifies branches, PRs, and work items that are going stale. Stale work causes
> merge conflicts, overlapping releases, and deployment bottlenecks. Run this regularly
> to keep the pipeline moving.
>
> This is a read-only check. It does not modify any state.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE @ Stale Check`** while this command
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

When this command is run, perform **all** of the following checks on the current repo,
then display the results. If both repos (frontend and backend) are accessible, run the
checks on both and report separately.

---

## Checks to Run

### 1. Stale Branches

List all remote branches and their last commit date. Flag branches by staleness tier:

```shell
# List all remote branches with last commit date, sorted oldest first
git fetch origin --quiet
git for-each-ref --sort=committerdate refs/remotes/origin --format='%(committerdate:short) %(committerdate:relative) %(refname:short)' | grep -v -E 'origin/(HEAD|main|master|staging|development)$'
```

**Staleness tiers:**

| Tier | Age | Emoji | Meaning |
|------|-----|-------|---------|
| Fresh | < 7 days | ✅ | Active work — no concern |
| Aging | 7–14 days | ⚠️ | Should be moving toward release soon |
| Stale | 14–21 days | 🟠 | At risk of merge conflicts and drift |
| Critical | > 21 days | ❌ | Likely to cause problems — needs action or cleanup |

### 2. Open PR Age

```shell
gh pr list --state open --json number,title,createdAt,headRefName,baseRefName,author,updatedAt --jq '.[] | "\(.number)\t\(.title)\t\(.createdAt)\t\(.headRefName)\t\(.baseRefName)\t\(.author.login)\t\(.updatedAt)"'
```

Flag PRs by age using the same staleness tiers as branches. Also flag:
- PRs with no activity (no updates) in the last 7 days
- PRs targeting `staging` or `master`/`main` (these should not exist under normal workflow)

### 3. Staging Idle Time

Check whether staging is clear and whether there is work ready to deploy:

```shell
# Is staging claimed?
git tag -l "staging/active"
git tag -n1 "staging/active"

# Are there branches that look ready to deploy? (merged PRs, release branches, etc.)
gh pr list --state open --json headRefName,baseRefName --jq '.[] | select(.baseRefName == "development" or .baseRefName == "main" or .baseRefName == "master") | .headRefName'

# How long has staging been clear? (last activity on staging branch)
git log origin/staging -1 --format='%ci %cr'
```

If staging is clear **and** there are branches or PRs that appear ready to ship,
flag that deployment capacity is being wasted:

> "Staging is clear and available, but there are X branches/PRs that may be ready
> to deploy. Consider starting the deployment process to keep the pipeline moving."

### 4. Branch Drift from Production

For every non-protected remote branch, check how far behind `main`/`master` it is:

```shell
# For each active branch, count commits it's behind main
for branch in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v -E '(HEAD|main|master|staging|development)$'); do
  behind=$(git rev-list --count "$branch..origin/main" 2>/dev/null || echo "0")
  if [ "$behind" -gt 0 ]; then
    echo "$branch is $behind commits behind main"
  fi
done
```

Flag drift severity:

| Drift | Emoji | Risk |
|-------|-------|------|
| 0–5 commits behind | ✅ | Low — easy merge |
| 6–15 commits behind | ⚠️ | Moderate — merge soon to avoid conflicts |
| 16–30 commits behind | 🟠 | High — conflicts likely |
| 30+ commits behind | ❌ | Critical — significant merge effort required |

### 5. Deployment Pipeline Queue

Summarise what's in the pipeline and in what order it should ship:

- Branches that look like release branches (version patterns like `X.Y.Z`)
- Branches that look like hotfixes (patch version patterns like `X.Y.Z` where Z > 0)
- Feature branches with open PRs targeting the release branch or `development`
- Any work that appears blocked or waiting

### 6. Time Since Last Production Release

```shell
gh release list --limit 1 --json tagName,createdAt --jq '.[0] | "\(.tagName) released \(.createdAt)"'
```

Calculate how long ago the last release was. Flag if it's been more than 2 weeks:

| Time Since Release | Emoji | Meaning |
|--------------------|-------|---------|
| < 7 days | ✅ | Recent release — healthy cadence |
| 7–14 days | ⚠️ | Getting long — check if work is ready to ship |
| 14–21 days | 🟠 | Overdue — pipeline may be stalled |
| > 21 days | ❌ | Significantly overdue — investigate blockers |

---

## Output Format

Display the results in this format:

**`🤓 DeployNOPE @ Stale Check`**

**Stale Work & Pipeline Health Check**
_Repo: `<owner>/<repo>` | Date: `<today>` | Branch: `<current-branch>`_

---

### Last Production Release

> `<version>` — released `<date>` (`<relative time>`) <emoji>

---

### Staging Status

> <status: "Clear and available" / "Claimed by <name> for <branch>">
> Last activity: `<date>` (`<relative time>`)
> <idle warning if applicable>

---

### Stale Branches

| Branch | Last Commit | Age | Behind `main` | Status |
|--------|-------------|-----|---------------|--------|
| `origin/<branch>` | `<date>` | `<relative>` | X commits | <emoji> <tier> |

If no stale branches: "All branches are fresh — no staleness detected."

---

### Open PRs

| PR | Title | Author | Opened | Last Updated | Target | Status |
|----|-------|--------|--------|-------------|--------|--------|
| #X | `<title>` | `<author>` | `<date>` | `<date>` | `<base>` | <emoji> <tier> |

If no open PRs: "No open PRs."

---

### Deployment Queue

List work in suggested deployment order:

1. **Hotfixes** (highest priority — ship first)
2. **Release branches** (next priority)
3. **Feature branches ready for release** (queue for next release)

If nothing is queued: "No work queued for deployment."

---

### Recommendations

Based on the findings, provide actionable recommendations. Examples:

- "Branch `feature/old-thing` is 3 weeks old and 22 commits behind main. Consider merging main into it or closing it if the work is abandoned."
- "PR #42 has had no activity for 12 days. Follow up with the author or close it."
- "Staging has been idle for 5 days with 2 branches ready to ship. Consider starting a deployment."
- "No releases in 18 days. Check if there are blockers preventing the next release."
- "All clear — pipeline is healthy and work is moving."

---

## Cross-Repo Check

If both repos are configured in `.deploynope.json` and accessible, run the checks on
both and add a cross-repo section:

### Cross-Repo Summary

| Check | Backend | Frontend |
|-------|---------|----------|
| Last release | `<version>` `<date>` | `<version>` `<date>` |
| Stale branches | X found | X found |
| Open PRs | X open | X open |
| Staging status | Clear / Claimed | Clear / Claimed |

Flag any version mismatch between repos.

---

## When to Run This

Suggest running this check:
- Before starting new work (`/deploynope-new-work`)
- At the start of each week
- When staging has been idle for more than a few days
- When planning which work to ship next
