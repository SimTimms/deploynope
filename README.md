
# DeployNOPE

<img width="256" height="1361" alt="nope" src="https://github.com/user-attachments/assets/60cd55ca-39f0-4117-b6d7-47b02ae26f71" />

DeployNOPE is a set of slash commands for [Claude Code](https://claude.ai/claude-code) that turns your AI assistant into a deployment co-pilot. It guides you through a safe, repeatable staging-to-production process and says "nope" any time you're about to do something risky.

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

You focus on whether the code works. DeployNOPE handles the "did we forget a step?" part.

---

## Commands


| Command | What it does |
|---------|--------------|
| `/deploy` | Loads the full deployment ruleset — staging contention, branch protection toggle, human gates, cross-repo checks. **Run this first** before any deployment work. |
| `/deploy-status` | Shows where you are in the deployment process. Detects whether you're doing a feature release, hotfix, or chore and displays the right checklist with your current progress. |
| `/release-manifest` | Creates a `releases/<version>.json` audit trail for every production deployment — who deployed, what SHAs, which Jira tickets, rollback status. |
| `/rollback` | Guides you through rolling back production to a previous release. Supports standard (through staging) and emergency (skip staging) modes. Handles frontend cache-busting automatically. |
| `/verify-rules` | A read-only self-check that confirms the deployment ruleset is loaded and Claude understands all 10 critical safety rules. Good for sanity-checking before a big release. |

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
for f in ~/GitHub/deploynope/commands/*.md; do
  ln -sf "$f" ~/.claude/commands/"$(basename "$f")"
done
```

### 4. Verify

Open a terminal in your project repo, start Claude Code, and type `/deploy`. If it loads the deployment ruleset, you're good to go.

---

## How it works

Claude Code loads slash commands from two places:

1. **Project-level:** `.claude/commands/` inside the current repository
2. **User-level:** `~/.claude/commands/` in your home directory

DeployNOPE lives in its own repo and symlinks into the user-level directory. That means the commands are available in every project without copying files around. Claude still runs in the context of whichever repo you're working in, so it has full access to that repo's git history, branches, and code.

### Typical workflow

1. Start Claude Code in your project repo
2. Type `/deploy` to load the ruleset
3. Type `/deploy-status` to see where you are
4. Follow the checklist — Claude will prompt you at every human gate
5. After deploying, `/release-manifest` creates the audit trail

---

## Updating

Pull the latest and the symlinks pick up the changes automatically:

```shell
cd ~/GitHub/deploynope && git pull
```

No need to re-create symlinks — they point to the files, not copies.

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
- Forgetting to merge back into `development`
- Forgetting GitHub Releases or Confluence notes
- Version mismatches between frontend and backend in production
- Leaving `master` unprotected after a force-push
- Basically anything that could ruin someone's afternoon
