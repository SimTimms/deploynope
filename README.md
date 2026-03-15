
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
- **Branch protection toggling** — temporarily unlocks production for a controlled reset, then immediately re-locks it (with state-file tracking to prevent resets without a verified unlock)
- **Stale release branch guard** — before resetting staging, verifies the release branch contains all commits on production, preventing accidental rewind
- **Config-driven branch names** — no hardcoded `master`/`main` assumptions; all branch names read from `.deploynope.json`
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
| `/deploynope-preflight` | Pre-deployment readiness check. Answers "am I clear to deploy?" — checks staging availability, branch drift, deployment timing, version parity, and more. |
| `/deploynope-new-work` | Starting a new task or branch? Runs the checklist: worktree check, branch name, base branch (branching policy), and branch drift check. Use before creating a branch. |
| `/deploynope-deploy-status` | Shows where you are in the deployment process. Detects whether you're doing a feature release, hotfix, or chore and displays the right checklist with your current progress. |
| `/deploynope-release-manifest` | Creates a `releases/<version>.json` audit trail for every production deployment — who deployed, what SHAs, which Jira tickets, rollback status. |
| `/deploynope-postdeploy` | Post-deployment completion check. Answers "am I actually done?" — checks branch protection, staging cleared, GitHub Releases, manifest, merge-back, and branch alignment. |
| `/deploynope-rollback` | Guides you through rolling back production to a previous release. Supports standard (through staging) and emergency (skip staging) modes. Handles frontend cache-busting automatically. |
| `/deploynope-stale-check` | Identifies stale branches, aging PRs, and pipeline bottlenecks. Helps keep the repo tidy and surfaces work that may have been forgotten. |
| `/deploynope-verify-rules` | A read-only self-check that confirms the deployment ruleset is loaded and Claude understands all 10 critical safety rules. Good for sanity-checking before a big release. |

---

## Stage Tags & Severity

When DeployNOPE is active, every response is tagged with `<emoji> DeployNOPE <context> · <Stage>` so you always know which stage of the workflow you're in and what release/branch it relates to. If the tag is missing from a deployment-related response, that's a red flag — the framework wasn't loaded.

**Severity:** `🤓` Normal | `⚠️` Caution (resets, force push) | `🚨` Alert (rollback, blocked)

| Context | Stage |
|---------|-------|
| Starting new work or `/deploynope-new-work` | `New Work` |
| Feature/ticket work (coding, committing) | `Feature` |
| `/deploynope-preflight` | `Preflight` |
| `/deploynope-configure` | `Configure` |
| `/deploynope-deploy-status` | `Deploy Status` |
| `/deploynope-verify-rules` | `Verify Rules` |
| `/deploynope-stale-check` | `Stale Check` |
| `/deploynope-release-manifest` | `Release Manifest` |
| `/deploynope-postdeploy` | `Post-Deploy` |
| `/deploynope-rollback` | `Rollback` |
| Staging contention check or claiming `<staging-branch>` | `Staging` |
| Validating on `<staging-branch>` | `Staging Validation` |
| Resetting `<production-branch>` / production deployment | `Production` |
| Creating a GitHub Release | `Release` |
| Post-deployment alignment check | `Post-Deploy` |
| General deployment work (no specific step) | `Deploy` |

**Examples:** `🤓 DeployNOPE 2.10.0 · Feature`, `⚠️ DeployNOPE 2.10.0 · Production`, `🚨 DeployNOPE 2.10.0 · Rollback`

---

## Quick start

### 1. Clone this repo

```shell
git clone https://github.com/<your-user>/deploynope.git ~/GitHub/deploynope
```

### 2. Run the installer

```shell
cd ~/GitHub/deploynope
./install.sh
```

This will:
- Symlink all `/deploynope-*` commands to `~/.claude/commands/`
- Symlink the hooks directory to `~/.claude/hooks/`
- Merge DeployNOPE hook entries into `~/.claude/settings.json` without replacing unrelated hook config or other settings keys

The hooks are what make DeployNOPE say "nope" — they intercept `git push`, `git commit`, `gh pr create`, and other commands **before** they run, blocking unsafe operations and requiring confirmation for everything else. Without the hooks installed, DeployNOPE's slash commands still work but the safety net is missing.

To uninstall: `./uninstall.sh` (removes only DeployNOPE-installed hook entries and symlinks)

### 3. Verify

Open a terminal in your project repo, start Claude Code, and type `/deploynope-deploy`. If it loads the deployment ruleset, you're good to go. The hooks fire automatically — try asking Claude to push to your configured `<production-branch>` and the hook will block it.

<details>
<summary>Manual installation (without the script)</summary>

**Symlink commands:**
```shell
mkdir -p ~/.claude/commands
for f in ~/GitHub/deploynope/.claude/commands/*.md; do
  ln -sf "$f" ~/.claude/commands/"$(basename "$f")"
done
```

**Symlink hooks:**
```shell
ln -sf ~/GitHub/deploynope/.claude/hooks ~/.claude/hooks
```

**Add hooks to `~/.claude/settings.json`:**

Merge the following into your existing `~/.claude/settings.json` (create the file if it doesn't exist). Replace `/Users/you` with your actual home directory path:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {"type": "command", "command": "/Users/you/.claude/hooks/check-git-commit.sh", "timeout": 10},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-git-push.sh", "timeout": 15},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-git-reset.sh", "timeout": 15},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-gh-pr-create.sh", "timeout": 10},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-gh-release.sh", "timeout": 10},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-gh-api-protection.sh", "timeout": 10},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-git-branch-delete.sh", "timeout": 10},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-git-tag.sh", "timeout": 10},
          {"type": "command", "command": "/Users/you/.claude/hooks/check-git-merge.sh", "timeout": 10}
        ]
      }
    ]
  }
}
```

If you already have a `settings.json` with other config (e.g. MCP servers), add the `hooks` key alongside your existing keys — don't replace the file.

</details>

### 4. (Optional) Add deploy rules to your project's CLAUDE.md

So that Claude **automatically** loads the deployment ruleset when you do deployment, PR, or release work (instead of you having to remember to run `/deploynope-deploy`), add the deploy rules to your repo's `CLAUDE.md` (or equivalent rules file).

1. Open **[CLAUDE-deploy-example.md](CLAUDE-deploy-example.md)** in this repo.
2. Copy the **"Deployment & PR Work"** section (the part under the horizontal rule) into your project's `CLAUDE.md`.
3. Remove or adjust any bullets that don't apply to your setup (e.g. repo-specific references).
4. Save. Claude Code will now see those rules when working in that repo and will prompt to run `/deploynope-deploy` before doing branches, PRs, pushes, deploys, version bumps, releases, or merge conflict resolution. When starting new work (new branch, new task), the rules can prompt for `/deploynope-new-work` so worktree and branching policy are checked.

This way, if someone asks Claude to merge a PR or deploy without having run `/deploynope-deploy` first, Claude will stop and load the ruleset before proceeding.

---

## How it works

Claude Code has two extension points that DeployNOPE uses:

1. **Slash commands** (`~/.claude/commands/`) — the `/deploynope-*` commands that guide you through workflows
2. **PreToolUse hooks** (`~/.claude/settings.json`) — shell scripts that fire **before** Claude executes a tool, letting DeployNOPE block or confirm dangerous operations

The installer symlinks both into your user-level Claude config. Commands are available in every project without copying files around. Hooks fire automatically in every Claude Code session — they intercept `git push`, `git commit`, `gh pr create`, and other commands before they run.

Claude still runs in the context of whichever repo you're working in, so it has full access to that repo's git history, branches, and code. The hooks read context from the current working directory (branch names, `.deploynope.json` config, etc.) to make per-project decisions.

### Typical workflow

1. Start Claude Code in your project repo
2. **First time?** Type `/deploynope-configure` to set up repo names, branches, Confluence, etc.
3. **Starting new work?** Type `/deploynope-new-work` to run the worktree + branching checklist, then create your branch
4. **Deploying?** Type `/deploynope-deploy` to load the ruleset
5. **Ready?** Type `/deploynope-preflight` to check if you're clear to deploy
6. Type `/deploynope-deploy-status` to see where you are
7. Follow the checklist — Claude will prompt you at every human gate
8. After deploying, `/deploynope-release-manifest` creates the audit trail
9. **Done?** Type `/deploynope-postdeploy` to confirm everything is closed out


---

## Removing project-level copies

If you previously had these commands inside a project's `.claude/commands/`, you can remove them once the symlinks are set up. The user-level commands apply across all projects.

---

## What DeployNOPE says NOPE to

- Pushing to `<production-branch>` without going through `<staging-branch>`
- Resetting `<staging-branch>` when someone else's work is there
- Deploying after 2:00 PM without explicit confirmation
- Skipping staging validation
- Deploying frontend before backend is confirmed healthy
- Inventing branch names (always asks you first)
- Starting a new branch without checking worktree and branching policy (run `/deploynope-new-work` first)
- Resetting production without a verified protection unlock (state-file guard)
- Deploying a stale release branch that would rewind production
- Deleting production, staging, or development branches
- Committing directly to protected branches without a warning
- Forgetting to merge back into `development`
- Forgetting GitHub Releases or Confluence notes
- Version mismatches between frontend and backend in production
- Leaving `<production-branch>` unprotected after a force-push
- Basically anything that could ruin someone's afternoon


---

## Tests

DeployNOPE includes a bash test suite covering all 9 hooks with 116 assertions. Tests create disposable git repos, simulate hook JSON input, and verify deny/ask/passthrough decisions.

```bash
./tests/run-tests.sh              # all tests
./tests/run-tests.sh push merge   # filter by hook name
```

See `tests/COVERAGE-MATRIX.md` for the full rule-to-test mapping.

---

## Releases

See [GitHub Releases](https://github.com/SimTimms/deploynope/releases) for the full version history and changelog.

---

## What's Next

- Choose a deployment strategy from a list or point it to a custom strategy document
- Choose a version strategy
