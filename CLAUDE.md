# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shared Salesforce DX project template used as a **git submodule** across all Corrao Group Salesforce projects. Contains unified tooling configs (ESLint, Prettier, Stylelint, Husky, Jest) and a sync script to keep consumer projects aligned.

This is NOT a deployable Salesforce project — it is a **configuration source of truth**.

## Commands

### Sync (run from consumer project, not from this repo)
```bash
npm run sync:preview                    # Dry-run — show what would change
npm run sync                            # Apply template configs to project
npm run sync:update                     # Pull latest template + apply
node sf-template/sync.js --force        # Apply without prompting
```

### Lint & Format (run from consumer project)
```bash
npm run lint                            # ESLint on Aura + LWC JS
npm run lint:slds                       # SLDS linter on src/
npm test                                # LWC Jest tests
npm run prettier                        # Format all src/ files
npm run prettier:verify                 # Check formatting without writing
```

### Test (run from consumer project)
```bash
npm run test:unit                                        # All LWC Jest tests
npm run test:unit:watch                                  # Watch mode
npm run test:unit:coverage                               # With coverage report
npx sfdx-lwc-jest -- --testPathPattern="componentName"   # Single component tests
```

### Install
```bash
npm install                             # Install all devDependencies
```

## Architecture

### Config Files (synced to consumer projects verbatim)

| File | Purpose |
|------|---------|
| `.prettierrc.yml` | Prettier: 4-space, single quotes, 180 width, es5 trailing commas, Apex/XML/LWC plugins |
| `eslint.config.mjs` | ESLint v9 flat config: Aura (ES5), LWC JS/TS, Jest tests/mocks, SLDS HTML linting |
| `.stylelintrc.json` | Stylelint with `@salesforce-ux/stylelint-plugin-slds` — 15 SLDS-specific CSS rules |
| `jest.config.js` | Spreads `sfdx-lwc-jest/config`, adds coverage reporting, `passWithNoTests: true` |
| `.editorconfig` | 4-space indent (2-space for JSON/YAML), LF endings, no final newline, 180 char width |
| `.npmrc` | Suppresses audit, fund, and deprecation noise on install |
| `.prettierignore` | Excludes staticresources, digitalExperiences, wave, .github, shell scripts |
| `.husky/pre-commit` | Branch guard + selective `<userPermissions>` stripping + `npx lint-staged` |

### Sync Script (`sync.js`)

The sync script is the core mechanism. It resolves paths relative to `__dirname`, so it only works when this repo lives as a submodule at `<project>/sf-template/`.

- **Copies** all config files listed above to the project root (overwrites)
- **Merges** `package.json`:
  - `devDependencies` — template versions win, project-specific extras preserved
  - `scripts` — only template-managed scripts updated (see `TEMPLATE_MANAGED_SCRIPTS` in sync.js); project-specific scripts like `open:*`, `package:*` are never touched
  - `engines`, `lint-staged` — overwritten from template
  - `name`, `version`, `workspaces`, `dependencies` — preserved from project
- **Adds** `sf-data-manager` git submodule if not present, ensures `workspaces` includes it, cleans up legacy `data-tool` workspace reference
- **Deletes** legacy config files (`.huskyrc`, `.eslintrc`, `.eslintrc.json`, `aura.eslintrc.json`, `lwc.eslint.json`, `.eslintignore`, `lint-staged.config.js`)
- **Fixes** `.gitignore` (`.husky/` → `.husky/_/` so hooks are committed)
- Flags: `--dry-run` (preview only), `--force` (apply without prompting)

### Pre-commit Hook Pipeline

The `.husky/pre-commit` hook runs three steps on every commit:

1. **Branch guard** — blocks direct commits to `main`, `dev`, `qa`, `uat`. Bypass with `--no-verify` or `ADMIN_OVERRIDE=1`.
2. **Profile cleanup** — uses Perl regex to strip all `<userPermissions>` blocks from staged `*.profile-meta.xml` files EXCEPT: `AuthorApex`, `InstallPackaging`, `InboundMigrationToolsUser`, `ManageAuthProviders`, `ModifyAllData`, `ModifyMetadata`. Modified files are re-staged automatically.
3. **lint-staged** — runs four tools by file pattern:
   - `prettier --write` on all formattable files (cls, cmp, css, html, js, json, md, xml, etc.)
   - `eslint` on Aura and LWC JS files
   - `sfdx-lwc-jest --bail --findRelatedTests` on LWC test files
   - `sf scanner run` on Apex files (cls, trigger, page, component)

### ESLint Flat Config Structure (`eslint.config.mjs`)

The ESLint config uses v9 flat config with 8 distinct blocks, each scoped by file pattern:

1. **Global ignores** — skips `eslint.config.*`, `jest.config.js`, `**/staticresources/**`
2. **Aura JS** (`**/aura/**/*.js`) — ES5, Aura recommended + Locker rules
3. **LWC JS** (`**/lwc/**/*.js`) — LWC recommended, latest ecmaVersion
4. **LWC TypeScript** (`**/lwc/**/*.ts`) — LWC + typescript-eslint, `no-explicit-any` off
5. **LWC JS Tests** (`**/lwc/**/*.test.js`) — LWC rules with `no-unexpected-wire-adapter-usages` off
6. **LWC TS Tests** (`**/lwc/**/*.test.ts`) — TypeScript test rules
7. **Jest Mocks** (`**/jest-mocks/**/*.js`) — standalone config with Jest globals
8. **SLDS HTML Linting** (`**/aura/**/*.cmp`, `**/lwc/**/*.html`) — HTML parser + SLDS BEM/deprecation rules

When adding new lint rules, identify the correct block by file pattern. Aura uses ES5 — do not add ES6+ rules there.

### Key Dependencies and Version Constraints

These peer dependency constraints are critical — violating them breaks `npm install`:

- `@salesforce/eslint-plugin-aura@3.0.0` requires `@eslint/js@^9` (NOT v10+)
- `@salesforce-ux/stylelint-plugin-slds@0.5.3` requires `stylelint@^16.10.0` (NOT v17+)
- `@salesforce/eslint-config-lwc@4.x` requires `@lwc/eslint-plugin-lwc@^3.0.0`
- ESLint v9 flat config (`eslint.config.mjs`) is incompatible with legacy `.eslintrc` — do NOT have both

## Code Style

- **Prettier**: 4-space tabs, single quotes, 180 char print width, trailing commas (es5), LF line endings
- **Apex**: `apexInsertFinalNewline: false` to match `sf source retrieve` format
- **JSON/YAML**: 2-space indent (via `.editorconfig` override)
- **ESLint**: ESLint v9 flat config only — no legacy `.eslintrc` files
- **Stylelint**: SLDS plugin rules (no `stylelint-prettier` bridge, no deprecated `unit-whitelist`)

## Consumer Project Setup

```bash
# Add as submodule (one-time)
git submodule add <repo-url> sf-template

# First sync
node sf-template/sync.js
npm install

# Ongoing updates
npm run sync:update
```

## What This Template Does NOT Include (project-specific)

- `sfdx-project.json` — package directories, API version, namespaces
- `.gitignore` — only patched (`.husky/` → `.husky/_/`), never overwritten
- `.env` — org aliases, credentials
- `config/*.yaml` — project-specific YAML config for sf-data-manager (template includes examples in `config/`)
- `post-merge` / `restore-org-config.sh` hooks (multi-org branch config)
- CI/CD workflows (`.github/workflows/`)
- `CLAUDE.md` for the consumer project
- The `test` script (top-level) — some projects run Apex tests, some don't
