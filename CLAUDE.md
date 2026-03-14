# CLAUDE.md — DeployNOPE Project Rules

## Auto-Activate DeployNOPE

If the user asks to do any of the following — **even without explicitly invoking a
`/deploynope-*` command** — you MUST load `/deploynope-deploy` first and tag all
responses with **`🤓 Protected by DeployNOPE`** before proceeding:

- Deploy, release, or ship code
- Push to `staging`, `master`, `main`, or production
- Reset `staging` or `master`
- Create a PR or merge a branch into `staging`, `master`, or `development`
- Create a GitHub Release or tag a version
- Bump a version number
- Roll back a deployment
- Start new work, create a feature branch, or create a hotfix branch
- Commit code (DeployNOPE may include commit naming conventions)

**Why:** DeployNOPE contains human gates, staging contention checks, cross-repo parity
rules, and branch protection procedures that prevent production incidents. If these rules
are not loaded, critical safety steps can be silently skipped. The user should never have
to remember to invoke DeployNOPE manually — it must activate automatically whenever
deployment-related work begins.

**How it works:**
1. When you detect a deployment-related request, load `/deploynope-deploy` (if not already loaded).
2. Tag your response with **`🤓 Protected by DeployNOPE`** to confirm the framework is active.
3. Follow all DeployNOPE rules for the duration of the workflow.
4. If the request does NOT match the triggers above, do not load DeployNOPE or tag responses.

## Confirmation Prompts Must Include the Tag

When DeployNOPE is active and you ask the user to confirm an action (commit, push, merge,
reset, release, etc.), the confirmation prompt **must** include a visible
**`🤓 Protected by DeployNOPE`** tag. This serves as a built-in signal:

- If the user sees the tag, they know DeployNOPE rules are governing the action.
- If the tag is missing, the user knows DeployNOPE is NOT active — and can stop and ask why.

Examples:
> "Ready to commit all of this? **`🤓 Protected by DeployNOPE`**"
> "Shall I push this to origin? **`🤓 Protected by DeployNOPE`**"
> "Ready to reset `master` to match `staging`? **`🤓 Protected by DeployNOPE`**"

The absence of the tag on a deployment-related confirmation is itself a red flag that
the framework was not loaded.
