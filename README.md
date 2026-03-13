
# DeployNOPE

<img width="256" height="1361" alt="nope" src="https://github.com/user-attachments/assets/60cd55ca-39f0-4117-b6d7-47b02ae26f71" />

DeployNOPE is a wrapper around your development AI. It is not concerned with coding standards or planning — its only focus is **branching strategy and deployment**.

It's a set of slash commands for [Claude Code](https://claude.ai/claude-code) that turns your AI assistant into a deployment co-pilot. It guides you through a safe, repeatable staging-to-production process and says "nope" any time you're about to do something risky.

It was built for a two-repo setup (frontend + backend) where both repos must stay version-locked, but the commands and safety patterns are useful for any team that deploys through a staging environment.

---

## Why use it?

Deployments have a lot of steps, and skipping one can ruin someone's afternoon. DeployNOPE keeps Claude honest by loading a strict ruleset that enforces:

- **Human gates** — Claude pauses and asks before every destructive action (push, reset, merge, delete)
- **Staging contention** — checks that nobody else is using staging before you claim it
- **Cross-repo version parity** — backend and frontend must be on the same version in production
- **Deployment timing** — warns you before deploying after 2:00 PM (peak traffic hours)
- **Branch protection toggling** — temporarily unlocks `master` for a controlled reset, then immediately re-locks it
- **Rollback procedures** — standard and emergency paths, including frontend cache-busting
- **Starting new work** — when you begin a new task, feature, or fix, the ruleset checks worktree usage, asks for branch name and base branch (following your branching policy), and runs a branch drift check before you create a branch. Run **`/deploynope-new-work`** to run this checklist explicitly.

You focus on whether the code works. DeployNOPE handles the "did we forget a step?" part.

---

## Commands

All commands are prefixed with `deploynope-` so they stay distinct in your slash-command list.

| Command | What it does |
|---------|--------------|
| `/deploynope-configure` | Interactive setup — prompts for repo names, branch names, Confluence details, deployment cutoff time, and more. Saves to `.deploynope.json` so other commands fill in placeholders automatically. |
| `/deploynope-deploy` | Loads the full deployment ruleset — staging contention, branch protection toggle, human gates, cross-repo checks. **Run this first** before any deployment work. |
| `/deploynope-new-work` | Starting a new task or branch? Runs the checklist: worktree check, branch name, base branch (branching policy), and branch drift check. Use before creating a branch. |
| `/deploynope-deploy-status` | Shows where you are in the deployment process. Detects whether you're doing a feature release, hotfix, or chore and displays the right checklist with your current progress. |
| `/deploynope-release-manifest` | Creates a `releases/<version>.json` audit trail for every production deployment — who deployed, what SHAs, which Jira tickets, rollback status. |
| `/deploynope-rollback` | Guides you through rolling back production to a previous release. Supports standard (through staging) and emergency (skip staging) modes. Handles frontend cache-busting automatically. |
| `/deploynope-verify-rules` | A read-only self-check that confirms the deployment ruleset is loaded and Claude understands all 10 critical safety rules. Good for sanity-checking before a big release. |

---

## Quick start

### 1. Clone this repo

```shell
git clone https://github.com/<your-user>/deploynope.git ~/GitHub/deploynope
```

### 2. Create the user-level commands directory

```shell
mkdir -p ~/.claude/commands
```

### 3. Symlink the commands

```shell
for f in ~/GitHub/deploynope/.claude/commands/*.md; do
  ln -sf "$f" ~/.claude/commands/"$(basename "$f")"
done
```

### 4. Verify

Open a terminal in your project repo, start Claude Code, and type `/deploynope-deploy`. If it loads the deployment ruleset, you're good to go.

### 5. (Optional) Add deploy rules to your project's CLAUDE.md

So that Claude **automatically** loads the deployment ruleset when you do deployment, PR, or release work (instead of you having to remember to run `/deploynope-deploy`), add the deploy rules to your repo's `CLAUDE.md` (or equivalent rules file).

1. Open **[CLAUDE-deploy-example.md](CLAUDE-deploy-example.md)** in this repo.
2. Copy the **"Deployment & PR Work"** section (the part under the horizontal rule) into your project's `CLAUDE.md`.
3. Remove or adjust any bullets that don't apply to your setup (e.g. repo-specific references).
4. Save. Claude Code will now see those rules when working in that repo and will prompt to run `/deploynope-deploy` before doing branches, PRs, pushes, deploys, version bumps, releases, or merge conflict resolution. When starting new work (new branch, new task), the rules can prompt for `/deploynope-new-work` so worktree and branching policy are checked.

This way, if someone asks Claude to merge a PR or deploy without having run `/deploynope-deploy` first, Claude will stop and load the ruleset before proceeding.

---

## How it works

Claude Code loads slash commands from two places:

1. **Project-level:** `.claude/commands/` inside the current repository
2. **User-level:** `~/.claude/commands/` in your home directory

DeployNOPE lives in its own repo and symlinks into the user-level directory. That means the commands are available in every project without copying files around. Claude still runs in the context of whichever repo you're working in, so it has full access to that repo's git history, branches, and code.

### Typical workflow

1. Start Claude Code in your project repo
2. **First time?** Type `/deploynope-configure` to set up repo names, branches, Confluence, etc.
3. **Starting new work?** Type `/deploynope-new-work` to run the worktree + branching checklist, then create your branch
4. **Deploying?** Type `/deploynope-deploy` to load the ruleset
5. Type `/deploynope-deploy-status` to see where you are
6. Follow the checklist — Claude will prompt you at every human gate
7. After deploying, `/deploynope-release-manifest` creates the audit trail


---

## Removing project-level copies

If you previously had these commands inside a project's `.claude/commands/`, you can remove them once the symlinks are set up. The user-level commands apply across all projects.

---

## What DeployNOPE says NOPE to

- Pushing to `master` without going through staging
- Resetting `staging` when someone else's work is there
- Deploying after 2:00 PM without explicit confirmation
- Skipping staging validation
- Deploying frontend before backend is confirmed healthy
- Inventing branch names (always asks you first)
- Starting a new branch without checking worktree and branching policy (run `/deploynope-new-work` first)
- Forgetting to merge back into `development`
- Forgetting GitHub Releases or Confluence notes
- Version mismatches between frontend and backend in production
- Leaving `master` unprotected after a force-push
- Basically anything that could ruin someone's afternoon
