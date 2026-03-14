# /deploynope-configure — Configure DeployNOPE for Your Project

> Interactive configuration for DeployNOPE. Prompts for all configurable values,
> suggests defaults where possible, and stores the result locally.
>
> Config is saved to `.deploynope.json` in the current project root.
> All other DeployNOPE commands read from this file to fill in placeholders.
>
> **Framework Visibility:** Tag every response with **`🤓 Protected by DeployNOPE`** while this command
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

### 14. Team Size

The number of developers on the team. This is stored for future use (e.g. contention
rules, review requirements).

**Default:** `1`

**Prompt:**
> "How many developers are on the team?
> Default: `1`"

**Config key:** `teamSize`

---

### 15. Commit Message Prefixes

Whether commit messages should include a conventional-commit-style prefix
(e.g. `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`).

When enabled, every commit proposed by DeployNOPE must include an appropriate prefix.
The prefix is chosen based on the nature of the change:

| Prefix | Use when |
|--------|----------|
| `feat` | Adding new functionality |
| `fix` | Fixing a bug |
| `chore` | Maintenance, dependency updates, config changes |
| `refactor` | Code restructuring with no behaviour change |
| `docs` | Documentation only |
| `test` | Adding or updating tests |

**Default:** `false`

**Prompt:**
> "Would you like to enforce commit message prefixes? (e.g. `feat: add login`,
> `fix: resolve null pointer`)
> Default: `false` (no prefixes)"

**Config key:** `commitPrefixes`

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
  "frontend": {
    "npmInstallCommand": "<value>"
  },
  "backend": {
    "npmInstallCommand": "<value>"
  },
  "teamSize": "<value>",
  "commitPrefixes": "<true or false>"
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
> | Frontend npm install | `<value>` |
> | Backend npm install | `<value>` |
> | Team size | `<value>` |
> | Commit prefixes | `<enabled or disabled>` |
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

If `.deploynope.json` is not found, the commands should still work but will use the
placeholder names as-is (current behaviour) and suggest running `/deploynope-configure`.
