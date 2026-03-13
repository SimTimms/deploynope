# Example: Add to your CLAUDE.md or project rules

Copy the section below into your repo's `CLAUDE.md` (or equivalent rules file) so Claude loads the DeployNOPE ruleset whenever deployment, PR, or release work is involved. Remove any references to specific repos (e.g. common-server) and keep only what applies to your setup.

---

## Deployment & PR Work

For all deployment, release, branching, versioning, PR, and code review tasks, the full ruleset must be loaded. Run `/deploynope-deploy` to load it.

- **When starting new work** (new task, feature, or branch), run `/deploynope-new-work` to check worktree, branch name, base branch (branching policy), and branch drift before creating a branch.
- **At the start of a deployment session**, running `/deploynope-verify-rules` confirms the ruleset is loaded and understood before proceeding.
- **To see current progress**, run `/deploynope-deploy-status` to show where you are in the deployment process (feature release, hotfix, or chore) and the right checklist.
- **After a production deployment**, use `/deploynope-release-manifest` to create the audit trail; use `/deploynope-rollback` when rolling back.

**If the user has not run `/deploynope-deploy` but asks Claude to do any of the following, Claude must stop, load `/deploynope-deploy` first, and then proceed:**

- Create, rename, or delete a branch
- Create, merge, or close a pull request
- Push to any branch
- Force-push or reset any branch
- Deploy to staging or production
- Bump a version number
- Create a GitHub Release
- Write or update release notes
- Perform a code review
- Resolve merge conflicts

> "Before I proceed, I need to load the deployment ruleset. Running `/deploynope-deploy` now."
