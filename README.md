# sf-template

Shared Salesforce DX project template used as a **git submodule** (at `.template/`) across all Corrao Group Salesforce projects. Contains unified configs for ESLint, Prettier, Stylelint, Husky, Jest, Claude Code, and VS Code — plus a sync script to keep consumer projects aligned.

This is **not** a deployable Salesforce project — it is a configuration source of truth.

## Quick Start: New Project

The fastest way to start a new project is from the [sf-project-template](https://github.com/nickmorozov/sf-project-template) GitHub template:

```bash
# 1. Create repo from template
gh repo create my-project --template nickmorozov/sf-project-template --clone --public
cd my-project

# 2. Run init (replaces placeholders, wires submodule, syncs configs, installs deps)
./init.zsh acme                                          # production org
./init.zsh https://acme--dev.sandbox.my.salesforce.com   # sandbox (full URL)
./init.zsh acme--dev                                     # sandbox (shorthand)
```

`init.zsh` does the following in order:

1. Replaces `PROJECT_NAME` placeholders in all tracked files with the org name
2. Initializes the `.template/` submodule (pulls this repo)
3. Runs `node .template/sync.js --force` (copies all configs to project root)
4. Runs `npm install`
5. Deletes itself, commits, and pushes
6. Offers to authenticate your Salesforce org via `sf org login web`

After init completes, the project is ready — you can `sf project retrieve start` or start building.

## Adding to an Existing Project

If you already have a Salesforce DX project and want to adopt the template:

```bash
# 1. Add as submodule (one-time)
git submodule add https://github.com/nickmorozov/sf-template.git .template -b main

# 2. Run first sync (preview what changes, then apply)
node .template/sync.js              # interactive: shows changes, asks to apply
node .template/sync.js --force      # non-interactive: applies immediately

# 3. Install dependencies
npm install

# 4. Commit
git add -A && git commit -m "chore: add sf-template"
```

## Updating

One command pulls the latest template and applies all changes:

```bash
npm run sync:update
```

This runs three steps:

1. `git submodule update --remote --recursive .template` — pulls latest template
2. `node .template/sync.js` — syncs configs to project root
3. `npm install` — installs any new/updated dependencies

Other sync commands:

| Command                | What it does                                    |
| ---------------------- | ----------------------------------------------- |
| `npm run sync`         | Apply template configs (no git pull)            |
| `npm run sync:preview` | Dry-run — show what would change, apply nothing |
| `npm run sync:update`  | Pull latest template + apply + npm install      |

## What Gets Synced

### Config files (copied verbatim)

| File                      | Purpose                                                           |
| ------------------------- | ----------------------------------------------------------------- |
| `.prettierrc.yml`         | Prettier: 4-space, single quotes, 180 width, Apex/XML/LWC plugins |
| `eslint.config.mjs`       | ESLint v9 flat config: Aura (ES5), LWC JS/TS, Jest, SLDS HTML     |
| `.stylelintrc.json`       | Stylelint with SLDS plugin — 15 CSS rules                         |
| `jest.config.js`          | Spreads `sfdx-lwc-jest/config`, coverage reporting                |
| `.editorconfig`           | 4-space indent (2-space for JSON/YAML), LF endings                |
| `.npmrc`                  | Suppresses audit/fund/deprecation noise                           |
| `.prettierignore`         | Excludes staticresources, digitalExperiences, etc.                |
| `.husky/pre-commit`       | Branch guard + profile cleanup + lint-staged                      |
| `.mcp.json`               | Salesforce MCP server config for Claude                           |
| `.vscode/settings.json`   | Search exclusions                                                 |
| `.vscode/extensions.json` | Recommended extensions                                            |
| `.vscode/launch.json`     | Apex Replay Debugger                                              |

### Claude Code files (copied verbatim, tracked in `CLAUDE_MANAGED_FILES`)

- 10 slash commands in `.claude/commands/`
- 3 agents in `.claude/agents/`
- 4 rule docs in `.claude/rules/`

### `.claude/settings.json` (additive merge)

Template hooks are added or updated; hooks you add yourself are preserved. Matching uses the first 50 characters of the hook prompt.

### `package.json` (smart merge)

| Section                                         | Behavior                                                             |
| ----------------------------------------------- | -------------------------------------------------------------------- |
| `devDependencies`                               | Template versions win; your extras preserved                         |
| `scripts`                                       | Only template-managed scripts updated; your custom scripts preserved |
| `engines`, `lint-staged`                        | Overwritten from template                                            |
| `name`, `version`, `workspaces`, `dependencies` | Preserved from your project                                          |

### Legacy cleanup (automatic)

Sync deletes outdated config files if found: `.huskyrc`, `.eslintrc`, `.eslintrc.json`, `aura.eslintrc.json`, `lwc.eslint.json`, `.eslintignore`, `lint-staged.config.js`.

## Commands Reference

All commands run from the **consumer project**, not from this repo.

### Sync

```bash
npm run sync                # Apply template configs
npm run sync:preview        # Dry-run — show what would change
npm run sync:update         # Pull latest + apply + npm install
```

### Lint & Format

```bash
npm run lint                # ESLint on Aura + LWC JS
npm run lint:slds           # SLDS linter on src/
npm run prettier            # Format all src/ files
npm run prettier:verify     # Check formatting (no writes)
```

### Test

```bash
npm run test:unit                                        # All LWC Jest tests
npm run test:unit:watch                                  # Watch mode
npm run test:unit:coverage                               # With coverage report
npx sfdx-lwc-jest -- --testPathPattern="componentName"   # Single component
```

### Source

```bash
npm run source:push         # Deploy to default org
npm run source:pull         # Retrieve from default org
npm run source:validate     # Dry-run deploy (validation only)
npm run source:diff         # Preview deploy + retrieve changes
npm run source:reset        # Reset source tracking
```

### Org

```bash
npm run org:open            # Open default org in browser
npm run org:list            # List all authenticated orgs
```

## Pre-commit Pipeline

The `.husky/pre-commit` hook runs on every commit:

1. **Branch guard** — blocks commits to `main`, `dev`, `qa`, `uat` (bypass: `ADMIN_OVERRIDE=1`)
2. **Profile cleanup** — strips non-essential `<userPermissions>` from profile XMLs
3. **lint-staged** — prettier, eslint, jest (related tests), sf scanner (Apex)

## What This Template Does NOT Include

These are project-specific and must be created/maintained per project:

- `sfdx-project.json` — package directories, API version, namespaces
- `.gitignore` — only patched (`.husky/` to `.husky/_/`), never overwritten
- `.env` — org aliases, credentials
- `CLAUDE.md` — project-specific Claude Code instructions
- CI/CD workflows (`.github/workflows/`)
- `config/*.yaml` — sf-data-manager YAML config
