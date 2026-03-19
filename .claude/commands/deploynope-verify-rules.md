# /deploynope-verify-rules — Deployment Ruleset Self-Check

> Run this at the start of any deployment session, or on demand, to verify that
> the deployment rules from `/deploynope-deploy` have been correctly loaded and understood.
>
> This is a non-destructive read-only check. It does not modify any state.
>
> **Framework Visibility:** Tag every response with **`🤓 DeployNOPE <context> · Verify Rules`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Instructions

When this command is run, perform the following self-check procedure:

1. For each rule check listed below, answer the question from your current understanding
   of the deployment rules loaded via `/deploynope-deploy`.
2. Compare your answer against the expected answer.
3. Mark the result as pass or fail.
4. Display the results table.
5. If any check fails, display the failure warning and refuse to proceed.
6. If all checks pass, display the confirmation message.

---

## Rule Checks

Answer each question based solely on the deployment rules currently loaded in this
conversation. Do not look anything up — this tests whether the rules are already
correctly understood.

| # | Question | Expected Answer |
|---|----------|-----------------|
| 1 | What must be checked before resetting staging? | Unreleased commits on <staging-branch> (`git log origin/<production-branch>..origin/<staging-branch>`) AND active claim tag (`git tag -l "staging/active"`). Both must be clear before proceeding. |
| 2 | Can changes be pushed directly to `<production-branch>`? | No. All changes reach <production-branch> via a controlled reset from `<staging-branch>`. No direct pushes, no PRs to `<production-branch>`. |
| 3 | What time restriction applies to deployments? | No deployment steps after 2:00 PM without explicit written confirmation from the user. |
| 4 | Which repo deploys first in a cross-repo release? | Backend first. Confirm CodePipeline is healthy before resetting frontend `<production-branch>`. |
| 5 | What must happen before any git push? | Human gate — always ask permission. Never push without explicit written confirmation. |
| 6 | What must be confirmed before resetting `<production-branch>`? | Staging validation sign-off from the user ("it's validated"). |
| 7 | What happens to <production-branch> branch protection during reset? | Force-push is temporarily enabled, the reset is performed, and force-push is immediately re-disabled. If the reset fails, <production-branch> is still re-locked immediately. |
| 8 | What is the <staging-branch> claim/clear lifecycle? | Claim (`staging/active` tag) before resetting staging. Clear only after <production-branch> has been reset and deployment is confirmed healthy. |
| 9 | What must match across repos before production deployment? | Version numbers in `package.json` must match on both frontend and backend. |
| 10 | What branch do all work types branch from? | `<default-base-branch>` (configured via `defaultBaseBranch` in `.deploynope.json`, falls back to `<production-branch>`). Hotfixes always branch from `<production-branch>` regardless of this setting. |

---

## Output Format

Display the results in exactly this format:

**Deployment Ruleset Verification**
_Date: `<today>` | Rules source: `/deploynope-deploy`_

| # | Rule Check | Expected Answer | Result |
|---|------------|-----------------|--------|
| 1 | Pre-staging-reset checks | Unreleased commits on <staging-branch> AND active claim tag | ✅ or ❌ |
| 2 | Direct pushes to <production-branch> | No — all changes go through <staging-branch> → <production-branch> reset | ✅ or ❌ |
| 3 | Deployment time restriction | No steps after 2:00 PM without explicit confirmation | ✅ or ❌ |
| 4 | Cross-repo deployment order | Backend first, confirm CodePipeline healthy before frontend | ✅ or ❌ |
| 5 | Pre-push requirement | Human gate — always ask permission | ✅ or ❌ |
| 6 | Pre-`<production-branch>`-reset confirmation | Staging validation sign-off from human | ✅ or ❌ |
| 7 | `<production-branch>` branch protection during reset | Temporarily enabled, reset performed, immediately re-locked. Re-lock even on failure. | ✅ or ❌ |
| 8 | Staging claim/clear lifecycle | Claim before reset, clear only after <production-branch> reset and deployment confirmed healthy | ✅ or ❌ |
| 9 | Cross-repo version parity | `package.json` version numbers must match on both repos | ✅ or ❌ |
| 10 | Base branch for all work types | `<production-branch>` | ✅ or ❌ |

---

## If Any Check Fails

Display:

> **⚠️ RULESET VERIFICATION FAILED**
>
> One or more deployment rules were not correctly understood. The following
> checks did not match the expected answers:
>
> - #X: `<rule check name>` — got `<your answer>`, expected `<expected answer>`
>
> **It is not safe to proceed with deployment work.** Please reload the deployment
> rules by running `/deploynope-deploy`, then re-run `/deploynope-verify-rules` to confirm.

Do not proceed with any deployment, branching, or release work until all checks pass.

---

## If All Checks Pass

Display:

> **Deployment ruleset verified — all 10 checks passed.**
>
> Rules are correctly loaded and understood. Safe to proceed with deployment work.
> Remember: when in doubt, do less and ask more.
