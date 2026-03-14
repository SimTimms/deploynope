# DeployNOPE Test Coverage Matrix

Maps every enforceable rule to its enforcement mechanism and test coverage.

## Legend

| Enforcement | Meaning |
|------------|---------|
| **Hook (deny)** | Hard block — hook returns `deny`, command cannot execute |
| **Hook (ask)** | Soft gate — hook returns `ask`, user must approve |
| **Command** | Rule enforced by AI via slash command instructions |
| **None** | Rule exists only as documentation — no mechanical enforcement |

## Hook Enforcement (Tested)

| # | Rule | Hook | Decision | Test File | Tests |
|---|------|------|----------|-----------|-------|
| 1 | Direct push to production (staging exists) | `check-git-push.sh` | **deny** | `test-hook-push.sh` | 4 |
| 2 | Force-with-lease push to production (reset step) | `check-git-push.sh` | ask | `test-hook-push.sh` | 2 |
| 3 | Push to production (no staging) | `check-git-push.sh` | ask+warn | `test-hook-push.sh` | 2 |
| 4 | Push to non-production branch | `check-git-push.sh` | ask | `test-hook-push.sh` | 2 |
| 5 | PR targeting production (main/master) | `check-gh-pr-create.sh` | **deny** | `test-hook-pr-create.sh` | 4 |
| 6 | PR targeting staging | `check-gh-pr-create.sh` | **deny** | `test-hook-pr-create.sh` | 2 |
| 7 | PR targeting development | `check-gh-pr-create.sh` | **deny** | `test-hook-pr-create.sh` | 3 |
| 8 | PR targeting release branch | `check-gh-pr-create.sh` | ask | `test-hook-pr-create.sh` | 3 |
| 9 | Merge non-production into development | `check-git-merge.sh` | **deny** | `test-hook-merge.sh` | 3 |
| 10 | Merge production into development (post-deploy) | `check-git-merge.sh` | ask | `test-hook-merge.sh` | 2 |
| 11 | Merge into production branch | `check-git-merge.sh` | ask+warn | `test-hook-merge.sh` | 2 |
| 12 | Merge into staging | `check-git-merge.sh` | ask+warn | `test-hook-merge.sh` | 2 |
| 13 | Every git commit | `check-git-commit.sh` | ask | `test-hook-commit.sh` | 6 |
| 14 | git reset --hard on production branch | `check-git-reset.sh` | ask | `test-hook-reset.sh` | 2 |
| 15 | git reset --hard on staging | `check-git-reset.sh` | ask | `test-hook-reset.sh` | 2 |
| 16 | git reset --hard on any branch | `check-git-reset.sh` | ask | `test-hook-reset.sh` | 2 |
| 17 | GitHub Release creation | `check-gh-release.sh` | ask | `test-hook-release.sh` | 5 |
| 18 | Branch protection PUT (enable/disable force-push) | `check-gh-api-protection.sh` | ask | `test-hook-api-protection.sh` | 4 |
| 19 | Local branch deletion | `check-git-branch-delete.sh` | ask | `test-hook-branch-delete.sh` | 3 |
| 20 | Remote branch deletion | `check-git-branch-delete.sh` | ask | `test-hook-branch-delete.sh` | 3 |
| 21 | Tag creation (incl. staging/active claim) | `check-git-tag.sh` | ask | `test-hook-tag.sh` | 3 |
| 22 | Tag deletion (incl. staging/active clear) | `check-git-tag.sh` | ask | `test-hook-tag.sh` | 2 |

## Bypass Resistance (Tested)

| # | Bypass Technique | Tested In | Hooks Covering |
|---|-----------------|-----------|----------------|
| 1 | `cd /tmp &&` prefix | commit, push, merge, pr-create, tag, branch-delete | All 9 hooks |
| 2 | `echo ok &&` chain | commit, pr-create, branch-delete | All 9 hooks |
| 3 | `echo ok \|\|` chain | commit | All 9 hooks |
| 4 | Semicolon prefix (`echo x;`) | commit | All 9 hooks |
| 5 | Multiple `&&` chains | commit | All 9 hooks |

## AI-Only Rules (Not Mechanically Enforced)

These rules are enforced solely by the AI following `/deploynope-deploy` instructions.
They are covered by `/deploynope-verify-rules` (manual self-check) but have **no hook**.

| # | Rule | Slash Command | Gap Risk |
|---|------|--------------|----------|
| 1 | Staging contention check (unreleased commits) | `/deploynope-deploy` | **High** — user could skip |
| 2 | Staging claim tag lifecycle (`staging/active`) | `/deploynope-deploy` | Medium — tag hook gates create/delete |
| 3 | Deployment time restriction (after 2:00 PM) | `/deploynope-deploy` | **High** — no time check in hooks |
| 4 | Cross-repo version parity | `/deploynope-deploy` | **High** — no automated check |
| 5 | Cross-repo deployment order (backend first) | `/deploynope-deploy` | Medium — process-dependent |
| 6 | Branch drift check before new work | `/deploynope-new-work` | Medium — process-dependent |
| 7 | Worktree safety check (no reset from worktree) | `/deploynope-deploy` | Low — rare scenario |
| 8 | Post-deployment branch alignment | `/deploynope-postdeploy` | Medium — checklist step |
| 9 | Release manifest creation | `/deploynope-release-manifest` | Medium — audit trail gap |
| 10 | Confluence release notes | `/deploynope-deploy` | Low — documentation only |
| 11 | Framework auto-activation (CLAUDE.md triggers) | `CLAUDE.md` | **High** — relies on AI reading CLAUDE.md |
| 12 | `Protected by DeployNOPE` tag on every response | `CLAUDE.md` | Medium — visibility only |

## Passthrough Safety (Tested)

Every hook is tested to confirm it does NOT intercept unrelated commands:

| Hook | Passthrough Commands Tested |
|------|-----------------------------|
| `check-git-commit.sh` | `git status`, `git log`, `npm install`, `echo "git commit"` |
| `check-git-push.sh` | `git pull`, `git status`, `npm run push` |
| `check-git-reset.sh` | `git reset --soft`, `git reset HEAD`, `echo reset --hard` |
| `check-gh-pr-create.sh` | `gh pr list`, `gh pr view`, `git status` |
| `check-git-merge.sh` | `git status`, `npm install`, `git merge --abort` |
| `check-gh-release.sh` | `gh release list`, `gh release view`, `git tag` |
| `check-gh-api-protection.sh` | GET protection, non-protection PUT, `curl` |
| `check-git-branch-delete.sh` | `git branch`, `git branch -a`, `git checkout -b` |
| `check-git-tag.sh` | `git tag -l`, `git tag -n`, `git tag` (bare), `npm version` |
