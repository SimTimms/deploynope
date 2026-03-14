# /deploynope-configure — Configure DeployNOPE for Your Project

> Interactive configuration for DeployNOPE. Prompts for all configurable values,
> suggests defaults where possible, and stores the result locally.
>
> Config is saved to `.deploynope.json` in the current project root.
> All other DeployNOPE commands read from this file to fill in placeholders.
>
> **Framework Visibility:** Tag every response with **`Protected by DeployNOPE`** while this command
> is active. See `/deploynope-deploy` § Framework Visibility for full details.

---

## Instructions

When this command is run, walk through each configuration section below **in order**.
For each setting:

1. **Check for an existing config** — read `.deploynope.json` in the current working directory.
   If it exists, show the current values as defaults.
2. **Try to suggest a value** using the detection method described for each setting.
3. **Prompt the user** — show the suggested value (if any) and ask them to confirm or override.
4. After all settings are collected, **write the config file** and display a summary.

---

## Settings

### 1. Repository Owner

The GitHub org or user that owns both repos.

**Detection:** Run `git remote get-url origin` and extract the owner from the URL.

**Prompt:**
> "GitHub owner/org — this is used in API calls for branch protection, releases, etc.
> Detected from this repo's origin: `<detected-owner>`
>
> Use `<detected-owner>`, or enter a different value:"

**Config key:** `owner`

---

### 2. Backend Repository Name

The GitHub repository name (not the full path) for the backend.

**Detection:** If the current repo's remote URL contains a recognisable name, suggest it.
Otherwise, no suggestion.

**Prompt:**
> "Backend repository name (just the repo name, not the full path):
> Example: `my-backend`
> Detected: `<suggestion or 'none detected'>`"

**Config key:** `backendRepo`

---

### 3. Frontend Repository Name

The GitHub repository name for the frontend.

**Detection:** No automatic detection (it's the other repo). If backend was detected,
suggest a common pattern (e.g., if backend is `foo-server`, suggest `foo-client` or
`foo-frontend`).

**Prompt:**
> "Frontend repository name:
> Example: `my-frontend`"

**Config key:** `frontendRepo`

---

### 4. Production Branch

The branch that represents production. Used throughout as the target for resets.

**Default:** `master`

**Detection:** Check if `master` or `main` exists:
```shell
git branch -r | grep -E 'origin/(master|main)$'
```

**Prompt:**
> "Production branch name:
> Detected: `<master or main>`
> Default: `master`"

**Config key:** `productionBranch`

---

### 5. Staging Branch

The branch used for staging validation before production.

**Default:** `staging`

**Prompt:**
> "Staging branch name:
> Default: `staging`"

**Config key:** `stagingBranch`

---

### 6. Development Branch

The integration branch that stays aligned with production after each release.

**Default:** `development`

**Detection:** Check for common names:
```shell
git branch -r | grep -E 'origin/(development|develop|dev)$'
```

**Prompt:**
> "Development/integration branch name:
> Detected: `<detected or 'development'>`
> Default: `development`"

**Config key:** `developmentBranch`

---

### 7. Deployment Cutoff Time

The time after which deployments require explicit confirmation.

**Default:** `14:00` (2:00 PM)

**Prompt:**
> "Deployment cutoff time (24-hour format, e.g. `14:00` for 2:00 PM).
> Deployments after this time will require explicit confirmation.
> Default: `14:00`"

**Config key:** `deploymentCutoffTime`

---

### 8. Confluence Space Key

The short key for the Confluence space where release notes are published.

**Default:** none

**Prompt:**
> "Confluence space key (e.g. `PROJ`, `ENG`).
> Leave blank if you don't use Confluence:"

**Config key:** `confluence.spaceKey`

---

### 9. Confluence Space ID

The numeric ID of the Confluence space.

**Default:** none

**Detection:** If the Atlassian Jira MCP server is available, attempt to look up spaces
and suggest one. Otherwise, no detection.

**Prompt:**
> "Confluence space ID (numeric, found in Confluence space settings).
> Leave blank if you don't use Confluence:"

**Config key:** `confluence.spaceId`

---

### 10. Confluence Cloud ID

The Atlassian Cloud ID (UUID format).

**Default:** none

**Prompt:**
> "Atlassian Cloud ID (UUID — found in Confluence admin or API).
> Leave blank if you don't use Confluence:"

**Config key:** `confluence.cloudId`

---

### 11. Confluence Release Notes Folder ID

The ID of the Confluence folder/page where release notes are organised.

**Default:** none

**Prompt:**
> "Confluence folder ID for release notes (numeric — the parent page ID).
> Leave blank if you don't use Confluence:"

**Config key:** `confluence.folderId`

---

### 12. Frontend NPM Install Command

The command used to regenerate `package-lock.json` on the frontend.

**Default:** `npm install --legacy-peer-deps`

**Prompt:**
> "Frontend lock file regeneration command:
> Default: `npm install --legacy-peer-deps`"

**Config key:** `frontend.npmInstallCommand`

---

### 13. Backend NPM Install Command

The command used to regenerate `package-lock.json` on the backend.

**Default:** `npm install`

**Prompt:**
> "Backend lock file regeneration command:
> Default: `npm install`"

**Config key:** `backend.npmInstallCommand`

---

### 14. Enable Changelog

Whether to maintain a changelog file that is updated with each release.

**Default:** `true`

**Prompt:**
> "Would you like to maintain a changelog file?
> This will automatically record changes for each release during the deployment process.
> Default: `true` (yes)"

**Config key:** `changelog.enabled`

---

### 15. Changelog Format

The format to use for changelog entries.

**Default:** `keepachangelog`

**Prompt (only if changelog is enabled):**
> "Changelog format:
> 1. `keepachangelog` — [Keep a Changelog](https://keepachangelog.com) format with Added/Changed/Fixed/Removed sections ← recommended
> 2. `simple` — flat list of changes per version with date
> 3. `conventional` — grouped by conventional commit type (feat/fix/chore/etc.)
>
> Default: `keepachangelog`"

**Config key:** `changelog.format`

---

### 16. Changelog File Path

The path to the changelog file, relative to the project root.

**Default:** `CHANGELOG.md`

**Prompt (only if changelog is enabled):**
> "Changelog file path (relative to project root):
> Default: `CHANGELOG.md`"

**Config key:** `changelog.filePath`

---

### 17. Auto-Populate Changelog from Commits

Whether to scan commit history between releases to pre-fill the changelog entry.

**Default:** `true`

**Prompt (only if changelog is enabled):**
> "Auto-populate changelog entries from commit history between releases?
> If enabled, commits will be scanned and grouped into the changelog entry for review
> before it is written. You will always have the chance to edit before it is saved.
> Default: `true` (yes)"

**Config key:** `changelog.autoPopulate`

---

### 18. Include Links in Changelog

Whether to include GitHub compare links between versions and links to PRs/issues.

**Default:** `true`

**Prompt (only if changelog is enabled):**
> "Include links in changelog entries?
> This adds GitHub compare links between versions and links to referenced PRs/issues.
> Default: `true` (yes)"

**Config key:** `changelog.includeLinks`

---

## Writing the Config

After all values are collected, write `.deploynope.json` to the project root:

```json
{
  "owner": "<value>",
  "backendRepo": "<value>",
  "frontendRepo": "<value>",
  "productionBranch": "<value>",
  "stagingBranch": "<value>",
  "developmentBranch": "<value>",
  "deploymentCutoffTime": "<value>",
  "confluence": {
    "spaceKey": "<value or null>",
    "spaceId": "<value or null>",
    "cloudId": "<value or null>",
    "folderId": "<value or null>"
  },
  "changelog": {
    "enabled": "<true or false>",
    "format": "<keepachangelog, simple, or conventional>",
    "filePath": "<value>",
    "autoPopulate": "<true or false>",
    "includeLinks": "<true or false>"
  },
  "frontend": {
    "npmInstallCommand": "<value>"
  },
  "backend": {
    "npmInstallCommand": "<value>"
  }
}
```

Set any blank/skipped values to `null`.

**[HUMAN GATE]** — Show the complete config and ask: "Does this look correct? I'll save
it to `.deploynope.json` in the project root."

After writing, display:

> **Configuration saved to `.deploynope.json`**
>
> | Setting | Value |
> |---------|-------|
> | Owner | `<value>` |
> | Backend repo | `<owner>/<backendRepo>` |
> | Frontend repo | `<owner>/<frontendRepo>` |
> | Production branch | `<value>` |
> | Staging branch | `<value>` |
> | Development branch | `<value>` |
> | Deployment cutoff | `<value>` |
> | Confluence space | `<spaceKey>` (ID: `<spaceId>`) |
> | Confluence cloud ID | `<cloudId>` |
> | Confluence folder ID | `<folderId>` |
> | Changelog enabled | `<value>` |
> | Changelog format | `<value or N/A>` |
> | Changelog file path | `<value or N/A>` |
> | Changelog auto-populate | `<value or N/A>` |
> | Changelog include links | `<value or N/A>` |
> | Frontend npm install | `<value>` |
> | Backend npm install | `<value>` |
>
> Other DeployNOPE commands will read from this file. Run `/deploynope-configure`
> again at any time to update.

---

## Re-running Configure

If `.deploynope.json` already exists when this command is run:

1. Read the existing config.
2. Show each current value as the default.
3. Only prompt for values the user wants to change — offer:

> "Existing configuration found. Would you like to:
> 1. Review and update all settings
> 2. Update specific settings only — tell me which ones
> 3. View the current configuration"

For option 2, only prompt for the settings the user mentions.
For option 3, display the summary table and stop.

---

## How Other Commands Use the Config

When any DeployNOPE command (deploy, rollback, deploy-status, release-manifest) is loaded,
it should check for `.deploynope.json` in the current working directory. If found, read
the values and substitute them for the placeholders:

| Placeholder | Config key |
|-------------|------------|
| `{owner}/{backend-repo}` | `<owner>/<backendRepo>` |
| `{owner}/{frontend-repo}` | `<owner>/<frontendRepo>` |
| `{confluence-space-key}` | `confluence.spaceKey` |
| `{confluence-space-id}` | `confluence.spaceId` |
| `{confluence-cloud-id}` | `confluence.cloudId` |
| `{confluence-folder-id}` | `confluence.folderId` |
| `master` (as production branch) | `productionBranch` |
| `staging` (as staging branch) | `stagingBranch` |
| `development` (as dev branch) | `developmentBranch` |
| `2:00 PM` (cutoff time) | `deploymentCutoffTime` |
| Changelog enabled | `changelog.enabled` |
| Changelog format | `changelog.format` |
| Changelog file path | `changelog.filePath` |
| Changelog auto-populate | `changelog.autoPopulate` |
| Changelog include links | `changelog.includeLinks` |

If `.deploynope.json` is not found, the commands should still work but will use the
placeholder names as-is (current behaviour) and suggest running `/deploynope-configure`.
