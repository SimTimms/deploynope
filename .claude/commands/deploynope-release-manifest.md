# /deploynope-release-manifest — Release Manifest

> Reference for writing release manifest files during deployment.
> The manifest is a structured JSON record of every production deployment,
> committed to the repo for auditability and rollback targeting.
>
> - **Backend:** `{owner}/{backend-repo}`
> - **Frontend:** `{owner}/{frontend-repo}`
>
> **Framework Visibility:** Tag every response with **`Protected by DeployNOPE`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Configuration

Check for `.deploynope.json` in the current working directory. If it exists, read it and
use its values in place of all placeholders throughout this command (see `/deploynope-configure`
for the full mapping). If it does not exist, use the placeholder names as-is and suggest:

> "Tip: run `/deploynope-configure` to set up your repo names, branch names, and Confluence
> details so they're filled in automatically."

---

## When to Write the Manifest

The release manifest is written **after creating the GitHub Release** and **before
writing Confluence release notes**. This positions it in the deployment process as
follows:

| Feature Release | Hotfix |
|---|---|
| Step 12: Create GitHub Release | Step 9: Create GitHub Release |
| **Step 12.5: Write release manifest** | **Step 9.5: Write release manifest** |
| Step 13: Merge release branch into `development` | Step 10: Merge hotfix branch into `development` |
| Step 14: Clear staging | Step 11: Notify in-flight branches |
| Step 15: Update changelog (if enabled) | Step 12: Clear staging |
| Step 16: Write Confluence release notes | Step 13: Update changelog (if enabled) |
| | Step 14: Write Confluence release notes |

Chore/config deployments do not require a manifest unless a version bump was involved.

---

## File Location

```
releases/<version>.json
```

Examples:
- `releases/6.51.0.json`
- `releases/6.52.0.json`

---

## Schema

| Field | Type | Description |
|---|---|---|
| `version` | string | The version string, e.g. `"6.51.0"` |
| `type` | string | One of `"feature"`, `"hotfix"`, or `"chore"` |
| `timestamp` | string | ISO 8601 UTC timestamp of the deployment |
| `deployer` | string | Name of the person who triggered the deployment (`git config user.name`) |
| `backend` | object | `{ sha, branch, repo, githubReleaseUrl }` |
| `frontend` | object | `{ sha, branch, repo, githubReleaseUrl }` |
| `jiraTickets` | string[] | Array of Jira ticket IDs included in this release (e.g. `["COG-1234", "COG-1235"]`) |
| `confluencePageUrl` | string \| null | URL of the Confluence release notes page. Set to `null` initially, updated after the page is written. |
| `previousVersion` | string | The version this release replaced. Critical for rollback targeting. |
| `status` | string | `"deployed"` or `"rolled-back"` |
| `rollback` | object \| null | `null` normally. If rolled back: `{ timestamp, reason, rolledBackTo }` |

---

## Example

```json
{
  "version": "6.51.0",
  "type": "feature",
  "timestamp": "2026-03-12T14:32:00Z",
  "deployer": "Jane Smith",
  "backend": {
    "sha": "a021eca40",
    "branch": "6.51.0",
    "repo": "{owner}/{backend-repo}",
    "githubReleaseUrl": "https://github.com/{owner}/{backend-repo}/releases/tag/v6.51.0"
  },
  "frontend": {
    "sha": "b3f9a7c12",
    "branch": "6.51.0",
    "repo": "{owner}/{frontend-repo}",
    "githubReleaseUrl": "https://github.com/{owner}/{frontend-repo}/releases/tag/v6.51.0"
  },
  "jiraTickets": ["PROJ-1234", "PROJ-1235", "PROJ-1240"],
  "confluencePageUrl": null,
  "previousVersion": "6.50.0",
  "status": "deployed",
  "rollback": null
}
```

After a rollback, the same file would be updated:

```json
{
  "version": "6.51.0",
  "status": "rolled-back",
  "rollback": {
    "timestamp": "2026-03-12T16:45:00Z",
    "reason": "Login flow regression on mobile",
    "rolledBackTo": "6.50.0"
  }
}
```

(All other fields remain unchanged; only `status` and `rollback` are updated.)

---

## Procedure

### Step 1: Gather the data

All of the required data should already be available at this point in the deployment
process. Collect:

- **version** — from `package.json` on the release branch
- **type** — ask the user if not obvious from context
- **timestamp** — current UTC time in ISO 8601
- **deployer** — `git config user.name`
- **backend sha** — `git rev-parse HEAD` on `master` after the reset (backend repo)
- **frontend sha** — `git rev-parse HEAD` on `master` after the reset (frontend repo)
- **branch** — the release/hotfix branch name
- **githubReleaseUrl** — from the GitHub Releases just created in the previous step
- **jiraTickets** — from PR descriptions, commit messages, or ask the user
- **previousVersion** — check the most recent existing manifest in `releases/`, or ask the user
- **confluencePageUrl** — set to `null`; will be updated after Confluence notes are written
- **status** — `"deployed"`
- **rollback** — `null`

### Step 2: Write the file

```shell
cat > releases/<version>.json << 'EOF'
{
  ... manifest contents ...
}
EOF
```

### Step 3: Commit directly to `master`

The manifest is committed **directly to `master`** after the master reset has already
completed. This is the recommended approach because:

- The release branch has already been merged/reset into `master` at this point.
  Committing to the release branch would require another reset cycle.
- The manifest is a post-deployment record, not a code change. It does not need
  staging validation.
- This keeps the deployment process linear — no backtracking.

```shell
git add releases/<version>.json
git commit -m "release: add manifest for <version>"
```

**[HUMAN GATE]** — Ask before pushing: "Shall I push the release manifest to `master`?"

```shell
git push origin master
```

> **Note:** This is a normal push (not a force-push), so branch protection does not
> need to be toggled. The push will succeed because `master` is not behind `origin/master`
> at this point — we just reset it.

### Step 4: Update after Confluence notes

After writing the Confluence release notes page, update the manifest:

```shell
jq '.confluencePageUrl = "<url>"' releases/<version>.json > tmp.json && mv tmp.json releases/<version>.json
```

Commit and push:

```shell
git add releases/<version>.json
git commit -m "release: add Confluence URL to <version> manifest"
```

**[HUMAN GATE]** — Ask before pushing.

---

## Rollback Updates

If a release is rolled back, update the manifest for the rolled-back version:

1. Set `status` to `"rolled-back"`.
2. Set `rollback` to `{ "timestamp": "<ISO 8601>", "reason": "<reason>", "rolledBackTo": "<version>" }`.
3. Commit and push to `master`.

The `previousVersion` field on the rolled-back manifest tells you what version was
running before the bad release. The `rollback.rolledBackTo` field confirms what version
production was reverted to (usually the same as `previousVersion`, but not always if
a specific older version was targeted).

---

## Safety

- **Never skip the manifest.** Every versioned deployment gets one.
- **Never fabricate data.** If a SHA, URL, or ticket ID is not available, set it to
  `null` and leave a comment in the commit message explaining why.
- **The manifest is append-only.** Never delete a manifest file. Rolled-back releases
  keep their manifest with updated `status` and `rollback` fields.
- **When in doubt, ask the user** for any value you cannot determine from git or GitHub.
