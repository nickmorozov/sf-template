# sf-project-template Scaffold Enrichment — Implementation Plan (Plan 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the bare `sf-project-template` org-pipeline scaffold into a mature, org-neutral starting tree that ships a complete, config-driven CI suite supporting **both** a source-delta deploy model and a 2GP package-deploy model, plus the full npm script families, docs, Postman skeleton, and config templates — re-pinned to the enriched `sf-template`.

**Architecture:** `sf-project-template` is the one-time "initial tree" layer (cloned via `gh repo create --template`); `sf-template` is the continuously-synced submodule layer at `.template/`. CI lives **here** (GitHub Actions cannot run from a submodule). A new `deployMode` key in `config/project.config.json` selects `source` (sfdx-git-delta delta deploy) or `package` (2GP build + install). Per-env deploy wrappers (`deploy-{dev,qa,uat,prod}.yml`) run a `config` job that reads `deployMode`, an `admin-guard` gate, then job-level `if:` selects one of two reusable engines (`sf-deploy-source.yml` / `sf-deploy-package.yml`) and ends with a reusable `slack-notify.yml`.

**Tech Stack:** GitHub Actions (reusable workflows via `workflow_call`), Salesforce CLI (`sf`), `sfdx-git-delta` plugin, SFDMU (`.template/sf-data-manager`), Node 24, npm scripts, `jq`, Slack Web API.

---

## Source-of-truth repos (present on disk in this workspace)

This plan uses a **vendor-and-neutralize** convention. The proven source files live in sibling repos in this workspace:

| Source repo      | Path                                      | Provides                                                                                                                                                                                                                  |
| ---------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bumble-bee-tpm` | `/Users/nick/Projects/Job/bumble-bee-tpm` | Source-delta CI (reusable `sf-deploy`, `admin-guard`, `slack-notify`, per-env `deploy-*`, `sf-backup`, `backup-sandboxes`, `stale-branches`), `backup-audit.js`, `MANUAL.md`, Postman skeleton, `config/repo-admins.json` |
| `cgpm`           | `/Users/nick/Projects/Job/cgpm`           | Package-deploy CI (`build-dev`, `deploy-qa`, `deploy-prod`, `code-analyzer`), the full `package:*`/`org:*`/`access:*`/`local:dev:*` npm script families, `config` block, `README-CI.md`, `SCRIPTS.md`                     |
| `sf-sync`        | `/Users/nick/Projects/Enum/sf-sync`       | `docs/adr/` Nygard format + index (ADR seed reference)                                                                                                                                                                    |

**Convention:** "Vendor `<source>` then neutralize" means `cp` the file, then apply the **exact** edits listed in that task. Every edit is shown in full — there are no "make it generic" placeholders. New files (mode-gating wrappers, `sf-deploy-package.yml`, config job, stubs, docs) are shown verbatim inline.

---

## Org-neutralization rules (apply to every vendored file)

These are the substitution sinks. A vendored file is org-neutral when **none** of these literals remain:

| Literal class       | Examples found in sources                                                                                                               | Neutralization target                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Org aliases         | `bumblebee-dev`, `cg-qa`, `cg-prod`, `cg-cgpm`                                                                                          | `<aliasPrefix>-<env>` derived from `config/project.config.json` `aliasPrefix`; in CI, the alias is a **workflow input**, never hardcoded          |
| Package name        | `CGPM` (in `sf package version create --package CGPM`)                                                                                  | `packageName` from config (CI reads `node scripts/node/config.js packageName`)                                                                    |
| Branch names        | `dev`, `qa`, `uat`, `main`                                                                                                              | The default `pipeline` array `["dev","qa","uat","main"]`; static `on: push:` triggers ship one wrapper per default-pipeline branch                |
| Extra orgs          | bumble's `int` / `INT` (5th org)                                                                                                        | **Dropped** from the template default; a project adds INT itself                                                                                  |
| Project data import | bumble's "TPM template data", `tpm/` dir, Tactic/Sales-Org logic                                                                        | Generic SFDMU import gated on `config/import.json` `_dataDir` diff (already generic in `sf-deploy.yml`); strip TPM-specific comments/choice-lists |
| Slack/Secrets       | `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`, `AER_LICENSE_KEY`, `SFDX_AUTH_URL`, `DEVHUB_AUTH_URL`, `ORG_AUTH_URL`, `CLAUDE_CODE_OAUTH_TOKEN` | Kept as GitHub **secret/var refs** (already org-neutral); documented per GitHub Environment in `docs/README-CI.md`                                |
| PII registries      | real GitHub logins / Slack IDs / SF usernames                                                                                           | Ship `config/repo-admins.json` + `config/slack-users.json` as **empty stubs**                                                                     |

---

## Prerequisites (MUST be true before Task 12)

- [ ] **P1 — Enriched `sf-template` is pushed.** Plan 1 landed on `sf-template` branch `feature/template-system-v2-spec` (NOT pushed per handoff). Task 12 re-pins `.template` to a GitHub ref. Before Task 12, push that branch (or merge to `main`) on `nickmorozov/sf-template`. Record the ref to pin to (`SF_TEMPLATE_REF`, e.g. `feature/template-system-v2-spec` or `main`).
- [ ] **P2 — Work happens on a feature branch of `sf-project-template`.** `cd /Users/nick/Projects/Job/sf-project-template && git checkout -b feature/scaffold-enrichment` (the scaffold's branch guard blocks direct commits to `main` once synced — use `--no-verify` for the pre-sync commits if needed, or commit before the husky hook is installed).

---

## File structure (what each task creates/modifies)

All paths relative to `/Users/nick/Projects/Job/sf-project-template` unless noted.

```
config/project.config.json            MODIFY  +deployMode, +per-env GitHub Environment doc
config/repo-admins.json               CREATE  empty stub []
config/slack-users.json               CREATE  empty stub {}
.github/workflows/
  admin-guard.yml                     CREATE  reusable (vendor bumble, as-is)
  slack-notify.yml                    CREATE  reusable (vendor bumble — superset w/ reviewers)
  sf-deploy-source.yml                CREATE  reusable source-delta engine (vendor bumble sf-deploy, neutralize)
  sf-deploy-package.yml               CREATE  reusable package build+install engine (NEW, distilled from cgpm)
  deploy-dev.yml                      CREATE  per-env wrapper (config→guard→[source|package]→notify)
  deploy-qa.yml                       CREATE  per-env wrapper
  deploy-uat.yml                      CREATE  per-env wrapper
  deploy-prod.yml                     CREATE  per-env wrapper (+promote/forward-merge in package mode)
  build-dev.yml                       CREATE  package-mode dev canary (vendor cgpm, neutralize, gate on deployMode)
  validate-pr.yml                     CREATE  PR validation (vendor bumble, neutralize, mode-aware dry-run)
  code-analyzer.yml                   CREATE  vendor cgpm, neutralize paths
  stale-branches.yml                  CREATE  vendor bumble, neutralize (derive base from pipeline)
  sf-backup.yml                       CREATE  vendor bumble, neutralize (add-on)
  backup-sandboxes.yml                CREATE  vendor bumble, neutralize matrix from pipeline (add-on)
  claude.yml                          CREATE  vendor cgpm/bumble (identical), as-is
  claude-code-review.yml              CREATE  vendor bumble (superset w/ slack notify)
package.json                          MODIFY  both script families + config block (config-contract-driven)
docs/
  README-CI.md                        CREATE  CI + required-secrets doc (rewrite, both modes)
  SCRIPTS.md                          CREATE  npm cheat-sheet (merge cgpm+bumble variants)
  MANUAL.md                           CREATE  per-env manual-step checklist (vendor bumble, neutralize)
  adr/README.md                       CREATE  ADR index (Nygard, vendor sf-sync format, empty index)
  adr/0001-record-architecture-decisions.md  CREATE  seed ADR (Nygard's canonical first ADR)
.postman/resources.yaml               CREATE  Postman sync manifest (empty cloud IDs)
postman/collections/.gitkeep          CREATE  empty collection dir
postman/environments/{dev,qa,uat,prod}.environment.yaml  CREATE  env files, blank values
postman/globals/workspace.globals.yaml CREATE  globals stub
.gitmodules                           MODIFY  re-pin .template branch to SF_TEMPLATE_REF
CLAUDE.md                             MODIFY  document scaffold layout, deployMode, CI
README.md                             MODIFY  scaffold quick-start

# In the sf-template repo (closes a Plan 1 gap that this scaffold's CI depends on):
/Users/nick/Projects/Job/sf-template/scripts/node/backup-audit.js   CREATE  (vendor bumble)
/Users/nick/Projects/Job/sf-template/config/project.config.json     MODIFY  +deployMode default
/Users/nick/Projects/Job/sf-template/scripts/node/config.js         MODIFY  +deployMode in DEFAULTS
/Users/nick/Projects/Job/sf-template/scripts/node/config.test.js    MODIFY  +deployMode assertion
```

---

## Task 1: Add `deployMode` to the org-neutrality contract (in `sf-template`)

The scaffold's CI selects its deploy engine from `deployMode`. The contract lives in the synced layer so every consumer reads it the same way. **Work in `/Users/nick/Projects/Job/sf-template` for this task.**

**Files:**

- Test: `/Users/nick/Projects/Job/sf-template/scripts/node/config.test.js`
- Modify: `/Users/nick/Projects/Job/sf-template/scripts/node/config.js`
- Modify: `/Users/nick/Projects/Job/sf-template/config/project.config.json`

- [ ] **Step 1: Write the failing test**

Add this `it` block inside the `describe('config', …)` block in `config.test.js`, after the existing "file values override defaults" test (line 33):

```javascript
it('defaults deployMode to source and allows override to package', () => {
    const def = readConfig(dir);
    assert.strictEqual(def.deployMode, 'source');
    fs.writeFileSync(path.join(dir, 'config', 'project.config.json'), JSON.stringify({ deployMode: 'package' }));
    const cfg = readConfig(dir);
    assert.strictEqual(cfg.deployMode, 'package');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/nick/Projects/Job/sf-template && node --test scripts/node/config.test.js`
Expected: FAIL — `def.deployMode` is `undefined`, assertion `undefined === 'source'` fails.

- [ ] **Step 3: Add `deployMode` to `DEFAULTS` in `config.js`**

In `scripts/node/config.js`, add `deployMode` to the `DEFAULTS` object (after `slackChannel`):

```javascript
const DEFAULTS = {
    githubOrg: '',
    projectName: 'PROJECT_NAME',
    aliasPrefix: '',
    pipeline: ['dev', 'qa', 'uat', 'main'],
    packageName: 'PROJECT_NAME',
    namespace: '',
    devHub: '',
    slackChannel: '',
    deployMode: 'source',
    aerNamespace: '',
    aerSkip: [],
};
```

Add the same key to `config/project.config.json` (after `slackChannel`):

```json
    "slackChannel": "",
    "deployMode": "source",
    "aerNamespace": "",
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/nick/Projects/Job/sf-template && node --test scripts/node/config.test.js`
Expected: PASS — all `config` tests green.

- [ ] **Step 5: Verify bash read path**

Run: `cd /Users/nick/Projects/Job/sf-template && node scripts/node/config.js deployMode`
Expected output: `source`

- [ ] **Step 6: Commit (in sf-template)**

```bash
cd /Users/nick/Projects/Job/sf-template
git add scripts/node/config.js scripts/node/config.test.js config/project.config.json
git commit -m "feat(config): add deployMode (source|package) to org-neutrality contract"
```

> NOTE: This commit lands on `sf-template`'s `feature/template-system-v2-spec` branch (the same branch Plan 1 used). It must be pushed before Task 12 (see Prerequisite P1).

---

## Task 2: Ship `backup-audit.js` in `sf-template` (closes Plan 1 gap)

`sf-backup.yml` (Task 10) calls `node scripts/node/backup-audit.js`. The spec places this file in the **synced** layer (`sf-template/scripts/node/`), but Plan 1 did not ship it. Add it now so the backup add-on is functional and `sync.js` propagates it to consumers. **Work in `/Users/nick/Projects/Job/sf-template`.**

**Files:**

- Create: `/Users/nick/Projects/Job/sf-template/scripts/node/backup-audit.js`

- [ ] **Step 1: Vendor the file from bumble-bee-tpm**

```bash
cp /Users/nick/Projects/Job/bumble-bee-tpm/scripts/node/backup-audit.js \
   /Users/nick/Projects/Job/sf-template/scripts/node/backup-audit.js
```

This file is already org-neutral (no aliases/org names; writes a generic `BACKUP-LOG.csv` from the Tooling API). No edits required. Confirm it matches the verbatim content captured in the harvest (Tooling-API audit: `SourceMember` → `User` name resolution → per-type `CreatedBy/LastModifiedBy` enrichment → CSV append).

- [ ] **Step 2: Verify it runs and self-documents usage**

Run: `cd /Users/nick/Projects/Job/sf-template && node scripts/node/backup-audit.js`
Expected: prints `Usage: backup-audit.js <org_alias> <org_name> <preview_json_path>` and exits non-zero. (Confirms the file parses and the arg-guard works without touching an org.)

- [ ] **Step 3: Confirm sync.js will propagate it**

`sync.js` recurses `scripts/` (Plan 1 keystone). Confirm the file is under a synced dir:

Run: `cd /Users/nick/Projects/Job/sf-template && node -e "console.log(require('fs').existsSync('scripts/node/backup-audit.js'))"`
Expected: `true`

- [ ] **Step 4: Commit (in sf-template)**

```bash
cd /Users/nick/Projects/Job/sf-template
git add scripts/node/backup-audit.js
git commit -m "feat(scripts): add backup-audit.js (Tooling-API change audit for sf-backup CI)"
```

---

## Task 3: Scaffold config files — `project.config.json` + PII stubs

Switch to the scaffold repo for the remainder of the plan. **Work in `/Users/nick/Projects/Job/sf-project-template` from here on unless a task says otherwise.**

**Files:**

- Modify: `config/project.config.json`
- Create: `config/repo-admins.json`
- Create: `config/slack-users.json`

- [ ] **Step 1: Seed the scaffold's `config/project.config.json`**

The scaffold currently has none of the v2 keys. Create/overwrite `config/project.config.json` with the full contract, `PROJECT_NAME` placeholders (substituted by `init.zsh`), and `deployMode` defaulting to `source`:

```json
{
    "githubOrg": "",
    "projectName": "PROJECT_NAME",
    "aliasPrefix": "PROJECT_NAME",
    "pipeline": ["dev", "qa", "uat", "main"],
    "packageName": "PROJECT_NAME",
    "namespace": "",
    "devHub": "",
    "slackChannel": "",
    "deployMode": "source",
    "aerNamespace": "",
    "aerSkip": []
}
```

- [ ] **Step 2: Create empty PII registry stubs**

`config/repo-admins.json` (array of GitHub logins; consumed by `admin-guard.yml` + `slack-notify.yml`):

```json
[]
```

`config/slack-users.json` (GitHub login → Slack member ID map; consumed by `slack-notify.yml`):

```json
{}
```

- [ ] **Step 3: Verify the config reads via the contract**

The scaffold does not yet have `.template/` synced, so `node scripts/node/config.js` is not available locally yet. Instead validate the JSON is well-formed:

Run: `cd /Users/nick/Projects/Job/sf-project-template && node -e "JSON.parse(require('fs').readFileSync('config/project.config.json','utf8')); JSON.parse(require('fs').readFileSync('config/repo-admins.json','utf8')); JSON.parse(require('fs').readFileSync('config/slack-users.json','utf8')); console.log('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit (in sf-project-template)**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add config/project.config.json config/repo-admins.json config/slack-users.json
git commit -m "feat(config): seed project.config.json contract + repo-admins/slack-users stubs"
```

---

## Task 4: Reusable gate + notify workflows (`admin-guard.yml`, `slack-notify.yml`)

Both are **already org-neutral** in bumble-bee-tpm (they read `config/repo-admins.json` / `config/slack-users.json` and use secret refs). Vendor verbatim. `slack-notify.yml` is bumble's superset (reviewer/assignee mentions); standardize on `secrets.SLACK_CHANNEL_ID` (NOT cgpm's `vars.` form).

**Files:**

- Create: `.github/workflows/admin-guard.yml`
- Create: `.github/workflows/slack-notify.yml`

- [ ] **Step 1: Vendor both files verbatim**

```bash
cd /Users/nick/Projects/Job/sf-project-template
mkdir -p .github/workflows
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/admin-guard.yml  .github/workflows/admin-guard.yml
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/slack-notify.yml .github/workflows/slack-notify.yml
```

- [ ] **Step 2: Verify org-neutrality (no edits expected)**

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -nEi 'bumble|tpm|cg-|corrao|tactic|sales.?org' .github/workflows/admin-guard.yml .github/workflows/slack-notify.yml || echo "CLEAN"`
Expected: `CLEAN`. (Both reference only `github.*` context, `config/*.json`, and `secrets.SLACK_BOT_TOKEN` / `secrets.SLACK_CHANNEL_ID`.)

Confirm key contracts:

- `admin-guard.yml`: `on: workflow_call: {}`; allows authors in `config/repo-admins.json` OR commits from a merged PR; else fails with a `feature/*`/`hotfix/*` guidance error.
- `slack-notify.yml`: `on: workflow_call` with inputs `workflow_name, result, pr_author, pr_number, pr_url, mention_reviewers, assignees, reviewers` and secrets `SLACK_BOT_TOKEN` (required), `SLACK_CHANNEL_ID` (required); posts threaded under a pinned `__PIPELINE_THREAD__` message; resolves GitHub login → Slack ID via `config/slack-users.json`.

- [ ] **Step 3: Lint the YAML**

Run: `cd /Users/nick/Projects/Job/sf-project-template && for f in .github/workflows/admin-guard.yml .github/workflows/slack-notify.yml; do node -e "require('child_process').execSync('python3 -c \"import yaml,sys; yaml.safe_load(open(sys.argv[1]))\" '+process.argv[1], {stdio:'inherit'})" "$f"; done && echo "YAML OK"`
Expected: `YAML OK` (or use `yamllint`/`actionlint` if available — the `.trunk` suite shipped by Plan 1 includes `actionlint`).

- [ ] **Step 4: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .github/workflows/admin-guard.yml .github/workflows/slack-notify.yml
git commit -m "ci: add reusable admin-guard + slack-notify workflows"
```

---

## Task 5: Source-delta engine (`sf-deploy-source.yml`)

Vendor bumble's `sf-deploy.yml` and strip the TPM-domain specifics (the `SALES_ORGS` Sales-Org filter and "TPM template data" wording). The delta logic (sfdx-git-delta, `[metadata]`/`[data]` commit markers, full-vs-delta, generic SFDMU import gated on `config/import.json` `_dataDir` diff) is already org-neutral and stays.

**Files:**

- Create: `.github/workflows/sf-deploy-source.yml`

- [ ] **Step 1: Vendor from bumble**

```bash
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/sf-deploy.yml \
   /Users/nick/Projects/Job/sf-project-template/.github/workflows/sf-deploy-source.yml
```

- [ ] **Step 2: Neutralize — exact edits**

In `.github/workflows/sf-deploy-source.yml`:

1. **Header comment** — replace the top comment block (lines 1–6, the "TPM template data" description) with:

```yaml
# Reusable workflow: Deploy Salesforce metadata to a single org via source-delta.
# Generates a delta package (sfdx-git-delta), detects changes, runs a full or
# delta deploy, and optionally imports SFDMU data when config/import.json's
# data dir changes. Called by per-environment deploy-*.yml wrappers.
#
# Respects repo variables: FULL_DEPLOY, FULL_DATA, SKIP_DEPLOY, SKIP_DATA.
# Commit-message markers (case-insensitive): [metadata] forces full deploy,
# [data] forces data import.
```

2. **`name:`** — change `name: Salesforce Deploy` → `name: Salesforce Deploy (source)`.

3. **Input description** — change the `import_data` input `description: Force TPM template data import (auto-detected from tpm/ changes)` → `description: Force SFDMU data import (auto-detected from config/import.json data-dir changes)`.

4. **Remove the `SALES_ORGS` plumbing** in the `Import ... data` step. Replace the entire `Import TPM data` step (the `- name: Import TPM data` block) with this generic step:

```yaml
- name: Import SFDMU data
  if: steps.data-check.outputs.should_import == 'true'
  env:
      TARGET_ALIAS: ${{ inputs.org_alias }}
      DELETE_FLAG: ${{ (inputs.delete_old_data == true || vars.DELETE_OLD_DATA == 'true') && '--delete' || '' }}
  run: |
      npm run data -- import -t "$TARGET_ALIAS" --verbose $DELETE_FLAG
```

5. **Rename the step** `- name: Export TPM data` does not exist here (that's sf-backup); only the import above. In the `Check for data changes` step, change the log string `echo "── Data files changed ──"` is generic — leave it. Remove the `SALES_ORGS: ${{ vars.SALES_ORGS }}` env line from the `Import SFDMU data` step (already removed in the replacement above) — confirm no other step references `SALES_ORGS`.

6. **Comment wording** — replace any remaining `TPM` mentions in comments (e.g. `# --- Data Import ---` is fine; the "automatic TPM template data import" comment) with `SFDMU`.

- [ ] **Step 3: Verify neutralization**

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -nEi 'tpm|sales.?org|bumble' .github/workflows/sf-deploy-source.yml || echo "CLEAN"`
Expected: `CLEAN`.

- [ ] **Step 4: Verify the engine contract is intact**

Confirm these are present (the delta engine):

- `on: workflow_call` with inputs `org_name, org_alias, environment, full, ignore_deploy_errors, import_data, delete_old_data` and output `skip_notify`.
- `sf sgd source delta --from HEAD~1 --to HEAD` delta generation gated on `is_full != 'true'`.
- `sf project deploy start` full path (`--test-level RunLocalTests`) and delta path (`--manifest deploy-package/package/package.xml`).
- Auth via `secrets.SFDX_AUTH_URL` (per GitHub Environment).

Run: `grep -c 'sfdx-git-delta\|sf sgd source delta\|SFDX_AUTH_URL' .github/workflows/sf-deploy-source.yml`
Expected: ≥ 3.

- [ ] **Step 5: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .github/workflows/sf-deploy-source.yml
git commit -m "ci: add reusable sf-deploy-source (sfdx-git-delta engine, org-neutral)"
```

---

## Task 6: Package engine (`sf-deploy-package.yml`) — NEW

A new reusable that distills cgpm's `deploy-qa.yml`/`deploy-prod.yml` into one parameterized engine: authenticate DevHub + target org, bump, build a 2GP version (beta or release), optionally promote, optionally install. The package name is read from the org-neutral contract (`node scripts/node/config.js packageName`), not hardcoded `CGPM`. Fails fast if `DEVHUB_AUTH_URL` is unset (spec edge case).

**Files:**

- Create: `.github/workflows/sf-deploy-package.yml`

- [ ] **Step 1: Create the file with this exact content**

```yaml
# Reusable workflow: 2GP package-deploy to a single org.
# Authenticates DevHub + target org, bumps the version, builds a package
# version (beta = --skip-validation, release = --code-coverage), optionally
# promotes it, and optionally installs it into the target org. The package
# name is read from config/project.config.json (packageName), never hardcoded.
# Called by per-environment deploy-*.yml wrappers when deployMode == package.
#
# Required secrets (per calling environment):
#   DEVHUB_AUTH_URL — sfdx auth URL for the Dev Hub
#   ORG_AUTH_URL    — sfdx auth URL for the target org (install only)

name: Salesforce Deploy (package)

on:
    workflow_call:
        inputs:
            org_name:
                required: true
                type: string
                description: Display name (e.g., QA, PROD)
            org_alias:
                required: true
                type: string
                description: Salesforce CLI alias to assign the target org
            environment:
                required: true
                type: string
                description: GitHub Environment for secret scoping
            build:
                required: false
                type: string
                default: 'beta'
                description: 'beta (skip-validation) or release (code-coverage)'
            promote:
                required: false
                type: boolean
                default: false
                description: Promote the built version (release flow)
            install:
                required: false
                type: boolean
                default: true
                description: Install the built version into the target org
        outputs:
            version:
                value: ${{ jobs.package.outputs.version }}
            package_version:
                value: ${{ jobs.package.outputs.package_version }}

jobs:
    package:
        name: ${{ inputs.build == 'release' && 'Release' || 'Beta' }} → ${{ inputs.org_name }}
        runs-on: ubuntu-latest
        environment: ${{ inputs.environment }}
        concurrency:
            group: sf-package-build
            cancel-in-progress: false
        outputs:
            version: ${{ steps.bump.outputs.version }}
            package_version: ${{ steps.build.outputs.package_version }}
        steps:
            - name: Checkout
              uses: actions/checkout@v5
              with:
                  fetch-depth: 0
                  submodules: recursive

            - name: Setup Node.js
              uses: actions/setup-node@v5
              with:
                  node-version: '24'
                  cache: 'npm'

            - name: Install dependencies
              run: npm ci

            - name: Install Salesforce CLI
              run: npm install --global @salesforce/cli

            - name: Resolve package name
              id: cfg
              run: |
                  PKG=$(node scripts/node/config.js packageName)
                  if [ -z "$PKG" ] || [ "$PKG" = "PROJECT_NAME" ]; then
                      echo "::error::packageName is not set in config/project.config.json"
                      exit 1
                  fi
                  echo "package_name=$PKG" >> "$GITHUB_OUTPUT"
                  echo "Package: $PKG"

            - name: Authenticate to DevHub
              env:
                  DEVHUB_AUTH_URL: ${{ secrets.DEVHUB_AUTH_URL }}
              run: |
                  if [ -z "$DEVHUB_AUTH_URL" ]; then
                      echo "::error::DEVHUB_AUTH_URL secret is not set — package mode requires a Dev Hub."
                      exit 1
                  fi
                  printf '%s' "$DEVHUB_AUTH_URL" > /tmp/devhub-auth.txt
                  sf org login sfdx-url --sfdx-url-file /tmp/devhub-auth.txt --alias devhub --set-default-dev-hub
                  rm -f /tmp/devhub-auth.txt

            - name: Authenticate to target org
              if: inputs.install
              env:
                  ORG_AUTH_URL: ${{ secrets.ORG_AUTH_URL }}
                  ORG_ALIAS: ${{ inputs.org_alias }}
              run: |
                  if [ -z "$ORG_AUTH_URL" ]; then
                      echo "::error::ORG_AUTH_URL secret is not set for environment ${{ inputs.environment }}."
                      exit 1
                  fi
                  printf '%s' "$ORG_AUTH_URL" > /tmp/org-auth.txt
                  sf org login sfdx-url --sfdx-url-file /tmp/org-auth.txt --alias "$ORG_ALIAS"
                  rm -f /tmp/org-auth.txt

            - name: Configure git
              run: |
                  git config user.name "github-actions[bot]"
                  git config user.email "github-actions[bot]@users.noreply.github.com"

            - name: Bump version
              id: bump
              run: |
                  if [ "${{ inputs.build }}" = "release" ]; then
                      VERSION=$(node scripts/node/bump.js minor)
                  else
                      VERSION=$(node scripts/node/bump.js patch)
                  fi
                  echo "version=$VERSION" >> "$GITHUB_OUTPUT"
                  echo "Bumped to $VERSION"

            - name: Build package version
              id: build
              env:
                  PKG: ${{ steps.cfg.outputs.package_name }}
              run: |
                  if [ "${{ inputs.build }}" = "release" ]; then
                      COV_FLAG="--code-coverage"
                  else
                      COV_FLAG="--skip-validation"
                  fi
                  BUILD_OUTPUT=$(sf package version create --package "$PKG" $COV_FLAG --installation-key-bypass --wait 120 --json) || true
                  STATUS=$(echo "$BUILD_OUTPUT" | jq -r '.status // 1')
                  if [ "$STATUS" != "0" ]; then
                      echo "::error::Package build failed"
                      echo "$BUILD_OUTPUT" | jq -r '.message // .result.Error // empty'
                      exit 1
                  fi
                  PACKAGE_VERSION=$(echo "$BUILD_OUTPUT" | jq -r '.result.SubscriberPackageVersionId')
                  if [ -z "$PACKAGE_VERSION" ] || [ "$PACKAGE_VERSION" = "null" ]; then
                      echo "::error::No SubscriberPackageVersionId in build output"
                      echo "$BUILD_OUTPUT" | jq .
                      exit 1
                  fi
                  echo "package_version=$PACKAGE_VERSION" >> "$GITHUB_OUTPUT"
                  echo "Built: $PACKAGE_VERSION"

            - name: Promote package version
              if: inputs.promote
              env:
                  PACKAGE_VERSION: ${{ steps.build.outputs.package_version }}
              run: sf package version promote --package "$PACKAGE_VERSION" --no-prompt

            - name: Install to ${{ inputs.org_name }}
              if: inputs.install
              env:
                  PACKAGE_VERSION: ${{ steps.build.outputs.package_version }}
                  ORG_ALIAS: ${{ inputs.org_alias }}
              run: |
                  sf package install --package "$PACKAGE_VERSION" --target-org "$ORG_ALIAS" \
                      --wait 120 --publish-wait 120 --no-prompt

            - name: Commit version files
              env:
                  VERSION: ${{ steps.bump.outputs.version }}
                  RELEASE: ${{ inputs.build == 'release' }}
              run: |
                  git add sfdx-project.json package.json
                  if git diff --cached --quiet; then
                      echo "No version changes to commit"
                      exit 0
                  fi
                  git diff --cached --stat
                  if [ "$RELEASE" = "true" ]; then
                      git commit -m "chore: release package version ${VERSION} [skip ci]"
                      git tag -a "v${VERSION}" -m "Release v${VERSION}"
                      git push --follow-tags
                  else
                      git commit -m "chore: ${{ inputs.org_name }} build v${VERSION} (beta) [skip ci]"
                      git push
                  fi
```

- [ ] **Step 2: Validate YAML + contract**

Run: `cd /Users/nick/Projects/Job/sf-project-template && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/sf-deploy-package.yml')); print('YAML OK')"`
Expected: `YAML OK`.

Run: `grep -c 'config.js packageName\|DEVHUB_AUTH_URL\|version promote\|package install' .github/workflows/sf-deploy-package.yml`
Expected: ≥ 4.

- [ ] **Step 3: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .github/workflows/sf-deploy-package.yml
git commit -m "ci: add reusable sf-deploy-package (2GP build/promote/install, config-driven name)"
```

---

## Task 7: Per-env deploy wrappers (`deploy-{dev,qa,uat,prod}.yml`)

One wrapper per default-pipeline branch. Each runs a `config` job (reads `deployMode` from `scripts/node/config.js`, present after init/sync), an `admin-guard` gate, then **two mutually-exclusive** engine jobs gated by mode, and a `slack-notify`. No separate `build-dev.yml` — the package-mode dev canary is `deploy-dev`'s package path (`install: false`).

Per-env behavior:

| Env  | branch | source path                          | package path                                                       |
| ---- | ------ | ------------------------------------ | ------------------------------------------------------------------ |
| dev  | `dev`  | deploy, `ignore_deploy_errors: true` | build `beta`, `install: false` (canary)                            |
| qa   | `qa`   | deploy                               | build `beta`, `install: true`                                      |
| uat  | `uat`  | deploy                               | build `beta`, `install: true`                                      |
| prod | `main` | deploy                               | build `release`, `promote: true`, `install: true`, + forward-merge |

**Files:** Create `.github/workflows/deploy-dev.yml`, `deploy-qa.yml`, `deploy-uat.yml`, `deploy-prod.yml`.

- [ ] **Step 1: Create `deploy-dev.yml`**

```yaml
# Deploy to DEV on every push to the dev branch.
# deployMode (config/project.config.json) selects the engine:
#   source  → sf-deploy-source (sfdx-git-delta)
#   package → sf-deploy-package (beta build, canary — no install)

name: Deploy to Dev

on:
    push:
        branches:
            - dev
    workflow_dispatch:
        inputs:
            full:
                description: 'Deploy all metadata (skip delta) — source mode only'
                type: boolean
                default: false
            import_data:
                description: 'Import SFDMU data after deploy — source mode only'
                type: boolean
                default: false
            delete_old_data:
                description: 'Delete old data before importing (clean import)'
                type: boolean
                default: false

concurrency:
    group: deploy-dev
    cancel-in-progress: false

permissions:
    contents: write
    actions: read
    pull-requests: read

jobs:
    config:
        name: Resolve deploy mode
        runs-on: ubuntu-latest
        outputs:
            mode: ${{ steps.read.outputs.mode }}
        steps:
            - uses: actions/checkout@v5
            - id: read
              run: |
                  MODE=$(node scripts/node/config.js deployMode)
                  echo "mode=$MODE" >> "$GITHUB_OUTPUT"
                  echo "deployMode: $MODE"

    admin-guard:
        if: github.event_name == 'push'
        uses: ./.github/workflows/admin-guard.yml

    deploy-source:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'source' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-source.yml
        with:
            org_name: DEV
            org_alias: dev
            environment: dev
            full: ${{ inputs.full == true }}
            ignore_deploy_errors: true
            import_data: ${{ inputs.import_data == true }}
            delete_old_data: ${{ inputs.delete_old_data == true }}
        secrets: inherit

    deploy-package:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'package' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-package.yml
        with:
            org_name: DEV
            org_alias: dev
            environment: dev
            build: beta
            promote: false
            install: false
        secrets: inherit

    notify:
        needs: [config, admin-guard, deploy-source, deploy-package]
        if: >-
            always() && !cancelled() &&
            (needs.admin-guard.result == 'failure' ||
             needs.deploy-source.result != 'skipped' ||
             needs.deploy-package.result != 'skipped')
        uses: ./.github/workflows/slack-notify.yml
        with:
            workflow_name: Deploy to Dev
            result: ${{ (needs.admin-guard.result == 'failure' || needs.deploy-source.result == 'failure' || needs.deploy-package.result == 'failure') && 'failure' || 'success' }}
        secrets:
            SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
            SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
```

- [ ] **Step 2: Create `deploy-qa.yml`** (branch `qa`; source = normal deploy; package = beta build + install)

```yaml
# Deploy to QA on every push to the qa branch.
# deployMode selects engine: source → sf-deploy-source; package → beta build + install.

name: Deploy to QA

on:
    push:
        branches:
            - qa
    workflow_dispatch:
        inputs:
            full:
                description: 'Deploy all metadata (skip delta) — source mode only'
                type: boolean
                default: false
            import_data:
                description: 'Import SFDMU data after deploy — source mode only'
                type: boolean
                default: false
            delete_old_data:
                description: 'Delete old data before importing (clean import)'
                type: boolean
                default: false

concurrency:
    group: deploy-qa
    cancel-in-progress: false

permissions:
    contents: write
    actions: read
    pull-requests: read

jobs:
    config:
        name: Resolve deploy mode
        runs-on: ubuntu-latest
        outputs:
            mode: ${{ steps.read.outputs.mode }}
        steps:
            - uses: actions/checkout@v5
            - id: read
              run: |
                  MODE=$(node scripts/node/config.js deployMode)
                  echo "mode=$MODE" >> "$GITHUB_OUTPUT"
                  echo "deployMode: $MODE"

    admin-guard:
        if: github.event_name == 'push'
        uses: ./.github/workflows/admin-guard.yml

    deploy-source:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'source' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-source.yml
        with:
            org_name: QA
            org_alias: qa
            environment: qa
            full: ${{ inputs.full == true }}
            import_data: ${{ inputs.import_data == true }}
            delete_old_data: ${{ inputs.delete_old_data == true }}
        secrets: inherit

    deploy-package:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'package' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-package.yml
        with:
            org_name: QA
            org_alias: qa
            environment: qa
            build: beta
            promote: false
            install: true
        secrets: inherit

    notify:
        needs: [config, admin-guard, deploy-source, deploy-package]
        if: >-
            always() && !cancelled() &&
            (needs.admin-guard.result == 'failure' ||
             needs.deploy-source.result != 'skipped' ||
             needs.deploy-package.result != 'skipped')
        uses: ./.github/workflows/slack-notify.yml
        with:
            workflow_name: Deploy to QA
            result: ${{ (needs.admin-guard.result == 'failure' || needs.deploy-source.result == 'failure' || needs.deploy-package.result == 'failure') && 'failure' || 'success' }}
        secrets:
            SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
            SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
```

- [ ] **Step 3: Create `deploy-uat.yml`** — identical to `deploy-qa.yml` with every `QA`→`UAT`, `qa`→`uat`, `Deploy to QA`→`Deploy to UAT`, `group: deploy-qa`→`group: deploy-uat`, and `branches: [qa]`→`branches: [uat]`. Full content:

```yaml
# Deploy to UAT on every push to the uat branch.
# deployMode selects engine: source → sf-deploy-source; package → beta build + install.

name: Deploy to UAT

on:
    push:
        branches:
            - uat
    workflow_dispatch:
        inputs:
            full:
                description: 'Deploy all metadata (skip delta) — source mode only'
                type: boolean
                default: false
            import_data:
                description: 'Import SFDMU data after deploy — source mode only'
                type: boolean
                default: false
            delete_old_data:
                description: 'Delete old data before importing (clean import)'
                type: boolean
                default: false

concurrency:
    group: deploy-uat
    cancel-in-progress: false

permissions:
    contents: write
    actions: read
    pull-requests: read

jobs:
    config:
        name: Resolve deploy mode
        runs-on: ubuntu-latest
        outputs:
            mode: ${{ steps.read.outputs.mode }}
        steps:
            - uses: actions/checkout@v5
            - id: read
              run: |
                  MODE=$(node scripts/node/config.js deployMode)
                  echo "mode=$MODE" >> "$GITHUB_OUTPUT"
                  echo "deployMode: $MODE"

    admin-guard:
        if: github.event_name == 'push'
        uses: ./.github/workflows/admin-guard.yml

    deploy-source:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'source' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-source.yml
        with:
            org_name: UAT
            org_alias: uat
            environment: uat
            full: ${{ inputs.full == true }}
            import_data: ${{ inputs.import_data == true }}
            delete_old_data: ${{ inputs.delete_old_data == true }}
        secrets: inherit

    deploy-package:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'package' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-package.yml
        with:
            org_name: UAT
            org_alias: uat
            environment: uat
            build: beta
            promote: false
            install: true
        secrets: inherit

    notify:
        needs: [config, admin-guard, deploy-source, deploy-package]
        if: >-
            always() && !cancelled() &&
            (needs.admin-guard.result == 'failure' ||
             needs.deploy-source.result != 'skipped' ||
             needs.deploy-package.result != 'skipped')
        uses: ./.github/workflows/slack-notify.yml
        with:
            workflow_name: Deploy to UAT
            result: ${{ (needs.admin-guard.result == 'failure' || needs.deploy-source.result == 'failure' || needs.deploy-package.result == 'failure') && 'failure' || 'success' }}
        secrets:
            SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
            SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
```

- [ ] **Step 4: Create `deploy-prod.yml`** (branch `main`; package = release + promote + install; adds a `forward-merge` job that runs in **both** modes after success to keep `qa`/`dev` from going stale)

```yaml
# Deploy to PRODUCTION on every push to main.
# deployMode selects engine: source → sf-deploy-source; package → release build + promote + install.
# After a successful deploy, forward-merges main → qa → dev (prevents stale-version build failures).

name: Deploy to Production

on:
    push:
        branches:
            - main
    workflow_dispatch:
        inputs:
            full:
                description: 'Deploy all metadata (skip delta) — source mode only'
                type: boolean
                default: false
            import_data:
                description: 'Import SFDMU data after deploy — source mode only'
                type: boolean
                default: false
            delete_old_data:
                description: 'Delete old data before importing (clean import)'
                type: boolean
                default: false

concurrency:
    group: deploy-prod
    cancel-in-progress: false

permissions:
    contents: write
    actions: read
    pull-requests: read

jobs:
    config:
        name: Resolve deploy mode
        runs-on: ubuntu-latest
        outputs:
            mode: ${{ steps.read.outputs.mode }}
        steps:
            - uses: actions/checkout@v5
            - id: read
              run: |
                  MODE=$(node scripts/node/config.js deployMode)
                  echo "mode=$MODE" >> "$GITHUB_OUTPUT"
                  echo "deployMode: $MODE"

    admin-guard:
        if: github.event_name == 'push'
        uses: ./.github/workflows/admin-guard.yml

    deploy-source:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'source' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-source.yml
        with:
            org_name: PROD
            org_alias: prod
            environment: prod
            full: ${{ inputs.full == true }}
            import_data: ${{ inputs.import_data == true }}
            delete_old_data: ${{ inputs.delete_old_data == true }}
        secrets: inherit

    deploy-package:
        needs: [config, admin-guard]
        if: always() && needs.config.outputs.mode == 'package' && (needs.admin-guard.result == 'success' || needs.admin-guard.result == 'skipped')
        uses: ./.github/workflows/sf-deploy-package.yml
        with:
            org_name: PROD
            org_alias: prod
            environment: prod
            build: release
            promote: true
            install: true
        secrets: inherit

    forward-merge:
        name: Forward-merge main → qa → dev
        needs: [deploy-source, deploy-package]
        if: >-
            always() && !cancelled() &&
            (needs.deploy-source.result == 'success' || needs.deploy-package.result == 'success')
        runs-on: ubuntu-latest
        steps:
            - name: Checkout (full history)
              uses: actions/checkout@v5
              with:
                  fetch-depth: 0
                  ref: main
            - name: Configure git
              run: |
                  git config user.name "github-actions[bot]"
                  git config user.email "github-actions[bot]@users.noreply.github.com"
            - name: Forward-merge to qa then dev
              run: |
                  for BRANCH in qa dev; do
                      git checkout "$BRANCH"
                      git pull --ff-only origin "$BRANCH"
                      git merge origin/main -m "chore: forward-merge from main [skip ci]" || {
                          echo "::warning::Auto-merge to $BRANCH failed (conflict). Manual merge required."
                          git merge --abort
                          continue
                      }
                      git push origin "$BRANCH" || echo "::warning::Push to $BRANCH failed."
                  done

    notify:
        needs: [config, admin-guard, deploy-source, deploy-package]
        if: >-
            always() && !cancelled() &&
            (needs.admin-guard.result == 'failure' ||
             needs.deploy-source.result != 'skipped' ||
             needs.deploy-package.result != 'skipped')
        uses: ./.github/workflows/slack-notify.yml
        with:
            workflow_name: Deploy to Production
            result: ${{ (needs.admin-guard.result == 'failure' || needs.deploy-source.result == 'failure' || needs.deploy-package.result == 'failure') && 'failure' || 'success' }}
        secrets:
            SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
            SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
```

- [ ] **Step 5: Validate all four wrappers**

Run:

```bash
cd /Users/nick/Projects/Job/sf-project-template
for f in deploy-dev deploy-qa deploy-uat deploy-prod; do
    python3 -c "import yaml; yaml.safe_load(open('.github/workflows/$f.yml')); print('$f OK')"
done
```

Expected: four `… OK` lines.

- [ ] **Step 6: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .github/workflows/deploy-dev.yml .github/workflows/deploy-qa.yml .github/workflows/deploy-uat.yml .github/workflows/deploy-prod.yml
git commit -m "ci: add per-env deploy wrappers (config-driven source|package mode gating)"
```

---

## Task 8: PR validation + code analyzer (`validate-pr.yml`, `code-analyzer.yml`)

`validate-pr.yml` is mode-agnostic: LWC Jest + Apex (aer) + a delta dry-run deploy against the PR's target-branch org. Vendor bumble's (the richer version: event classification, already-merged short-circuit, PR-target rules, threaded Slack). The **only** neutralization is replacing the LFS `bin/aer` step with the D4 install-not-vendor approach (`scripts/aer/install-aer.sh`, shipped by Plan 1). `code-analyzer.yml` is vendored from cgpm (already org-neutral).

**Files:**

- Create: `.github/workflows/validate-pr.yml`
- Create: `.github/workflows/code-analyzer.yml`

- [ ] **Step 1: Vendor both**

```bash
cd /Users/nick/Projects/Job/sf-project-template
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/validate-pr.yml .github/workflows/validate-pr.yml
cp /Users/nick/Projects/Job/cgpm/.github/workflows/code-analyzer.yml         .github/workflows/code-analyzer.yml
```

- [ ] **Step 2: Neutralize the aer step in `validate-pr.yml`**

Find the `aer-validate` job's two steps (`- name: Checkout (with LFS for bin/aer)` and `- name: Run Apex tests`) and replace **both** with:

```yaml
- name: Checkout
  uses: actions/checkout@v4

- name: Run Apex tests (aer)
  env:
      AER_LICENSE_KEY: ${{ secrets.AER_LICENSE_KEY }}
  run: |
      if [ -z "$AER_LICENSE_KEY" ]; then
          echo "::error::AER_LICENSE_KEY secret is not configured for this repository."
          exit 1
      fi
      bash scripts/aer/install-aer.sh
      mkdir -p ~/.local/share/aer
      printf '%s' "$AER_LICENSE_KEY" > ~/.local/share/aer/license.key
      # aer detects GITHUB_ACTIONS and changes output; clear it for the native renderer.
      _GA="${GITHUB_ACTIONS:-}"
      unset GITHUB_ACTIONS
      bash scripts/shell/run_aer_suites.sh
      export GITHUB_ACTIONS="$_GA"
```

Also update the job comment above `aer-validate` (`# Binary lives at bin/aer (LFS-tracked)…`) to: `# aer is installed on the runner via scripts/aer/install-aer.sh (D4: install, not vendor).`

- [ ] **Step 3: Confirm no other neutralization needed**

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -nEi 'bin/aer|lfs|tpm|bumble|sales.?org|cg-' .github/workflows/validate-pr.yml || echo "CLEAN"`
Expected: `CLEAN`. The branch list (`dev, qa, uat, main`) matches the default pipeline; auth uses `secrets.SFDX_AUTH_URL` per Environment; Slack uses `secrets.SLACK_BOT_TOKEN`/`SLACK_CHANNEL_ID`. Leave them.

- [ ] **Step 4: Confirm `code-analyzer.yml` is neutral**

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -nEi 'tpm|bumble|cg-|corrao' .github/workflows/code-analyzer.yml || echo "CLEAN"`
Expected: `CLEAN`. Its `paths:` (`src/main/**/classes/**`, `…/triggers/**`, `…/lwc/**`, `…/aura/**`) assume the `src/main/default` layout the scaffold uses — correct, leave as-is.

- [ ] **Step 5: Validate YAML**

Run:

```bash
cd /Users/nick/Projects/Job/sf-project-template
for f in validate-pr code-analyzer; do python3 -c "import yaml; yaml.safe_load(open('.github/workflows/$f.yml')); print('$f OK')"; done
```

Expected: `validate-pr OK`, `code-analyzer OK`.

- [ ] **Step 6: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .github/workflows/validate-pr.yml .github/workflows/code-analyzer.yml
git commit -m "ci: add validate-pr (aer via install-not-vendor) + code-analyzer"
```

---

## Task 9: Claude bots (`claude.yml`, `claude-code-review.yml`)

Vendor bumble's pair (superset: `claude-code-review.yml` posts a threaded Slack pointer). Both are org-neutral (use `secrets.CLAUDE_CODE_OAUTH_TOKEN`).

**Files:**

- Create: `.github/workflows/claude.yml`
- Create: `.github/workflows/claude-code-review.yml`

- [ ] **Step 1: Vendor both**

```bash
cd /Users/nick/Projects/Job/sf-project-template
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/claude.yml             .github/workflows/claude.yml
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/claude-code-review.yml .github/workflows/claude-code-review.yml
```

- [ ] **Step 2: Verify neutrality + Slack wiring**

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -nEi 'tpm|bumble|cg-|corrao' .github/workflows/claude.yml .github/workflows/claude-code-review.yml || echo "CLEAN"`
Expected: `CLEAN`. Confirm `claude-code-review.yml`'s `notify` job `uses: ./.github/workflows/slack-notify.yml` (the reusable shipped in Task 4) and passes `SLACK_BOT_TOKEN` + `SLACK_CHANNEL_ID`.

- [ ] **Step 3: Validate YAML + commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
for f in claude claude-code-review; do python3 -c "import yaml; yaml.safe_load(open('.github/workflows/$f.yml')); print('$f OK')"; done
git add .github/workflows/claude.yml .github/workflows/claude-code-review.yml
git commit -m "ci: add Claude Code + Claude Code Review bots"
```

---

## Task 10: Backup + stale-branch add-ons (`sf-backup.yml`, `backup-sandboxes.yml`, `stale-branches.yml`)

D6 = all add-ons on. Vendor bumble's three, neutralizing the INT 5th-org and TPM-data specifics. `sf-backup.yml` calls `node scripts/node/backup-audit.js` (shipped to the synced layer in Task 2).

**Files:**

- Create: `.github/workflows/sf-backup.yml`
- Create: `.github/workflows/backup-sandboxes.yml`
- Create: `.github/workflows/stale-branches.yml`

- [ ] **Step 1: Vendor all three**

```bash
cd /Users/nick/Projects/Job/sf-project-template
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/sf-backup.yml        .github/workflows/sf-backup.yml
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/backup-sandboxes.yml .github/workflows/backup-sandboxes.yml
cp /Users/nick/Projects/Job/bumble-bee-tpm/.github/workflows/stale-branches.yml   .github/workflows/stale-branches.yml
```

- [ ] **Step 2: Neutralize `sf-backup.yml`**

1. In the `workflow_dispatch.inputs.org_name.options` and `org_alias.options` lists, **remove the `INT` / `int` entries**. Result: `org_name` options `DEV, QA, UAT, PROD`; `org_alias` options `dev, qa, uat, prod`.

2. In the `Backup` job's `environment:` expression, remove the `int` branch:

```yaml
environment: ${{ inputs.org_alias == 'dev' && 'dev' || inputs.org_alias == 'qa' && 'qa' || inputs.org_alias == 'uat' && 'uat' || 'prod' }}
```

3. Replace the `Export TPM data` step (which uses `SALES_ORGS`) with a generic SFDMU export:

```yaml
- name: Export SFDMU data
  run: |
      npm run data -- export -s "$ORG_ALIAS" --verbose
```

4. Update the header comment: replace "exports TPM template data" / "TPM template data records" wording with "exports SFDMU data". The `node scripts/node/backup-audit.js "$ORG_ALIAS" "$ORG_NAME" /tmp/retrieve-preview.json` call stays unchanged (the script is now in the synced layer).

- [ ] **Step 3: Neutralize `backup-sandboxes.yml`**

1. Remove the `INT` entry from the `workflow_dispatch.inputs.org.options` list (leave `ALL, DEV, QA, UAT, PROD`).
2. Remove the `INT` row from the `matrix.include` list. Final matrix (maps each org to its source branch in the default pipeline):

```yaml
matrix:
    include:
        - org_name: DEV
          org_alias: dev
          source_branch: dev
          backup_branch: backup/dev
        - org_name: QA
          org_alias: qa
          source_branch: qa
          backup_branch: backup/qa
        - org_name: UAT
          org_alias: uat
          source_branch: uat
          backup_branch: backup/uat
        - org_name: PROD
          org_alias: prod
          source_branch: main
          backup_branch: backup/prod
```

- [ ] **Step 4: `stale-branches.yml` needs no edits** — it compares `origin/feature/*` against `origin/dev` (the default-pipeline integration branch) and posts PR comments. Confirm:

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -nEi 'tpm|bumble|cg-|corrao|int\b' .github/workflows/stale-branches.yml || echo "CLEAN"`
Expected: `CLEAN`.

- [ ] **Step 5: Verify all three neutralized + valid**

```bash
cd /Users/nick/Projects/Job/sf-project-template
grep -nEi 'tpm|sales.?org|bumble| INT\b|int:' .github/workflows/sf-backup.yml .github/workflows/backup-sandboxes.yml || echo "CLEAN"
for f in sf-backup backup-sandboxes stale-branches; do python3 -c "import yaml; yaml.safe_load(open('.github/workflows/$f.yml')); print('$f OK')"; done
```

Expected: `CLEAN`, then three `… OK` lines. (`sf-backup.yml` still references `scripts/node/backup-audit.js` — that's intended; the script ships via the synced layer.)

- [ ] **Step 6: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .github/workflows/sf-backup.yml .github/workflows/backup-sandboxes.yml .github/workflows/stale-branches.yml
git commit -m "ci: add sf-backup + backup-sandboxes + stale-branches add-ons (org-neutral)"
```

---

## Task 11: `package.json` — both script families + config block

Author the scaffold's `package.json` with the **scaffold-owned** scripts only (the families `sync.js` preserves). Template-managed scripts (`lint`, `test:unit*`, `prettier*`, `source:push/pull/diff/validate/reset/compile`, `org:open`, `org:list`, `data*`, `test:apex*`, `test:lwc`, `test:local*`, `promote:*`, `package:bump:*`, `sync*`, `precommit`, `prepare`, `update`) are injected by `sync.js` at init from `sf-template` — do **not** define them here. Aliases derive from the project name via `init.zsh`'s `PROJECT_NAME` substitution (the `config` block); CI reads its own values from `config/project.config.json`.

**Files:**

- Modify: `package.json`

- [ ] **Step 1: Write the full scaffold `package.json`**

```json
{
    "name": "PROJECT_NAME",
    "private": true,
    "version": "1.0.0",
    "description": "Salesforce project for PROJECT_NAME",
    "license": "UNLICENSED",
    "workspaces": [".template/sf-data-manager"],
    "config": {
        "prettier_glob": "**/*.{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}",
        "jq_version": ".result[-1].SubscriberPackageVersionId",
        "hide_warnings": "Skipping validation|sf package install|Warning: Record types|org-capitalize-record-types",
        "wait": "120",
        "package_name": "PROJECT_NAME",
        "dev_alias": "PROJECT_NAME-dev",
        "qa_alias": "PROJECT_NAME-qa",
        "uat_alias": "PROJECT_NAME-uat",
        "prod_alias": "PROJECT_NAME-prod",
        "admin_set": "Admin",
        "user_set": "User"
    },
    "scripts": {
        "source:diff:push": "dotenv -- sf project deploy preview",
        "source:diff:pull": "dotenv -- sf project retrieve preview",
        "source:push:force": "npm run source:push -- --ignore-conflicts",
        "source:pull:force": "npm run source:pull -- --ignore-conflicts",
        "source:sync": "((npm run source:diff:push | grep 'Will') && npm run source:push || echo 'Nothing To Deploy\\n') && ((npm run source:diff:pull | grep 'Will') && npm run source:pull || echo 'Nothing To Retrieve')",
        "source:sync:force": "((npm run source:diff:push | grep 'Conflicts') && npm run source:push:force || echo 'No Deploy Conflicts\\n') && ((npm run source:diff:pull | grep 'Conflicts') && npm run source:pull:force || echo 'No Retrieve Conflicts')",
        "test": "npm run test:lwc && npm run test:apex",
        "test:all": "dotenv -- bash scripts/shell/full_test.sh",
        "test:lwc:watch": "npm run test:lwc -- --watch",
        "test:lwc:debug": "npm run test:lwc -- --debug",
        "test:lwc:coverage": "npm run test:lwc -- --coverage",
        "package:list:": "dotenv -- sf package version list",
        "package:list:all": "dotenv -- sf package version list --verbose",
        "package:build": "dotenv -- sf package version create --package $npm_package_config_package_name --code-coverage --installation-key-bypass --wait $npm_package_config_wait 2>&1 | grep -vE \"$npm_package_config_hide_warnings\" && git add sfdx-project.json && git commit -m 'chore: release package version' && git tag -a \"v$npm_package_version\" -m \"Release v$npm_package_version\" && git push --follow-tags",
        "package:build:beta": "dotenv -- sf package version create --package $npm_package_config_package_name --skip-validation --installation-key-bypass --wait $npm_package_config_wait 2>&1 | grep -vE \"$npm_package_config_hide_warnings\" && git add sfdx-project.json && git commit -m 'chore: release package version (beta)'",
        "package:build:patch": "npm run package:bump:patch && npm run package:build",
        "package:build:minor": "npm run package:bump:minor && npm run package:build",
        "package:build:major": "npm run package:bump:major && npm run package:build",
        "package:promote": "dotenv -- sf package version promote --package \"$(sf package version list --json | jq -r $npm_package_config_jq_version)\" --no-prompt",
        "package:install:beta": "npm run package:build:beta && npm run package:install:qa:wait",
        "package:install:qa": "dotenv -- sf package install --package \"$(sf package version list --json | jq -r $npm_package_config_jq_version)\" --target-org \"${QA_ALIAS:-$npm_package_config_qa_alias}\" --no-prompt",
        "package:install:qa:wait": "npm run package:install:qa -- --wait $npm_package_config_wait --publish-wait $npm_package_config_wait --no-prompt",
        "package:install:uat": "dotenv -- sf package install --package \"$(sf package version list --json | jq -r $npm_package_config_jq_version)\" --target-org \"${UAT_ALIAS:-$npm_package_config_uat_alias}\" --wait $npm_package_config_wait --publish-wait $npm_package_config_wait --no-prompt",
        "package:install:prod": "dotenv -- sf package install --package \"$(sf package version list --json | jq -r $npm_package_config_jq_version)\" --target-org \"${PROD_ALIAS:-$npm_package_config_prod_alias}\" --wait $npm_package_config_wait --publish-wait $npm_package_config_wait --no-prompt",
        "package:install:all": "npm run package:install:qa ; npm run package:install:uat ; npm run package:install:prod",
        "package:deploy:beta": "npm run package:bump:patch && npm run package:install:beta",
        "package:deploy:patch": "npm run package:build:patch && npm run package:promote && npm run package:install:all",
        "package:deploy:minor": "npm run package:build:minor && npm run package:promote && npm run package:install:all",
        "package:deploy:major": "npm run package:build:major && npm run package:promote && npm run package:install:all",
        "package:deploy": "((npm run package:build:patch && npm run package:promote) || (npm run package:build:minor && npm run package:promote)) && npm run package:install:all",
        "ci:package:bump:patch": "node scripts/node/bump.js patch",
        "ci:package:bump:minor": "node scripts/node/bump.js minor",
        "ci:package:build:beta": "sf package version create --package $npm_package_config_package_name --skip-validation --installation-key-bypass --wait $npm_package_config_wait 2>&1 | grep -vE \"$npm_package_config_hide_warnings\"",
        "ci:package:build": "sf package version create --package $npm_package_config_package_name --code-coverage --installation-key-bypass --wait $npm_package_config_wait 2>&1 | grep -vE \"$npm_package_config_hide_warnings\"",
        "ci:package:promote": "sf package version promote --package \"$(sf package version list --json | jq -r $npm_package_config_jq_version)\" --no-prompt",
        "ci:package:install": "sf package install --package \"$PACKAGE_VERSION\" --target-org \"$TARGET_ALIAS\" --wait $npm_package_config_wait --publish-wait $npm_package_config_wait --no-prompt",
        "ci:test:node": "node --test scripts/node/*.test.js",
        "org:auth": "node scripts/node/auth.js",
        "org:delete": "dotenv -- sf org logout -o \"${TARGET_ALIAS:-$npm_package_config_dev_alias}\" --no-prompt",
        "org:create": "npm run org:delete; dotenv -- sf org create scratch --definition-file config/project-scratch-def.json --alias \"${TARGET_ALIAS:-$npm_package_config_dev_alias}\" --duration-days 30 --set-default && npm run org:init && npm run org:open",
        "org:init": "npm run source:push && npm run access:assign:all && npm run debug:toggle && npm run data:import",
        "org:open:dev": "dotenv -- sf org open --target-org \"${DEV_ALIAS:-$npm_package_config_dev_alias}\"",
        "org:open:qa": "dotenv -- sf org open --target-org \"${QA_ALIAS:-$npm_package_config_qa_alias}\"",
        "org:open:uat": "dotenv -- sf org open --target-org \"${UAT_ALIAS:-$npm_package_config_uat_alias}\"",
        "org:open:prod": "dotenv -- sf org open --target-org \"${PROD_ALIAS:-$npm_package_config_prod_alias}\"",
        "debug:toggle": "dotenv -- sf apex run --file scripts/apex/toggleDebugMode.apex | grep -iE 'USER_DEBUG|FAIL|SUCCESS'",
        "access:assign:admin": "dotenv -- sf org assign permset --name $npm_package_config_admin_set",
        "access:assign:user": "dotenv -- sf org assign permset --name $npm_package_config_user_set",
        "access:assign:all": "npm run access:assign:user && npm run access:assign:admin",
        "update:latest:check": "dotenv -- npx npm-check-updates",
        "update:latest:apply": "dotenv -- npx npm-check-updates -u && dotenv -- npm install",
        "git:commit": "git add -A && git commit -m 'chore: update all'",
        "git:commit:force": "ADMIN_OVERRIDE=true npm run git:commit",
        "org:config:log:schedule": "dotenv -- sf apex run --file scripts/apex/scheduleLogCleanup.apex | grep -iE 'USER_DEBUG|FAIL|SUCCESS'",
        "org:config:log:schedule:qa": "dotenv -- sf apex run --file scripts/apex/scheduleLogCleanup.apex --target-org \"${QA_ALIAS:-$npm_package_config_qa_alias}\" | grep -iE 'USER_DEBUG|FAIL|SUCCESS'",
        "org:config:log:schedule:uat": "dotenv -- sf apex run --file scripts/apex/scheduleLogCleanup.apex --target-org \"${UAT_ALIAS:-$npm_package_config_uat_alias}\" | grep -iE 'USER_DEBUG|FAIL|SUCCESS'",
        "org:config:log:schedule:prod": "dotenv -- sf apex run --file scripts/apex/scheduleLogCleanup.apex --target-org \"${PROD_ALIAS:-$npm_package_config_prod_alias}\" | grep -iE 'USER_DEBUG|FAIL|SUCCESS'",
        "local:dev": "dotenv -- sf lightning dev",
        "local:dev:app": "npm run local:dev -- app --device-type=desktop",
        "local:dev:site": "npm run local:dev -- site",
        "local:dev:cmp": "npm run local:dev -- component",
        "backmerge": "npm run promote -- --back",
        "backmerge:local": "npm run promote -- --no-stage --back",
        "backmerge:from-qa": "npm run backmerge -- qa",
        "backmerge:from-uat": "npm run backmerge -- uat",
        "backmerge:from-main": "npm run backmerge -- main",
        "open:code": "code .",
        "open:idea": "idea .",
        "open:log": "open CHANGE-LOG.csv"
    },
    "devDependencies": {
        "dotenv-cli": "^11.0.0"
    }
}
```

> NOTES:
>
> - `package:bump:{patch,minor,major}`, `promote:*`, `source:push/pull/validate/reset/compile`, `data:*`, `test:apex*`, `test:lwc`, `test:local*`, `test:unit*`, `org:open`, `org:list`, `lint*`, `prettier*`, `sync*`, `precommit`, `prepare`, `update` are **added by `sync.js`** from `sf-template` at init — that's why they're absent here yet referenced (e.g. `package:build:patch` calls `package:bump:patch`).
> - `dotenv-cli` is the only scaffold-specific devDep; `sync.js` merges the rest of `devDependencies` from `sf-template` (template versions win, this extra preserved).
> - `data:test:bulk` / `data:reset` from cgpm are intentionally **omitted** — they call project-specific apex (`createLargeTestProject.apex`, `deleteAllData.apex`) that `sf-template` does not ship.

- [ ] **Step 2: Validate JSON**

Run: `cd /Users/nick/Projects/Job/sf-project-template && node -e "JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('package.json OK')"`
Expected: `package.json OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add package.json
git commit -m "feat(scripts): add scaffold-owned package/org/access/local-dev/source script families"
```

---

## Task 12: Re-pin `.template` submodule to the enriched `sf-template`

**Depends on Prerequisite P1** (enriched `sf-template` pushed). Re-point the submodule branch from the current `main` pin to the enriched ref, and update the working tree.

**Files:**

- Modify: `.gitmodules`

- [ ] **Step 1: Confirm P1 is satisfied**

Run: `git ls-remote https://github.com/nickmorozov/sf-template <SF_TEMPLATE_REF>` (where `<SF_TEMPLATE_REF>` is the branch/ref from P1, e.g. `feature/template-system-v2-spec` or `main` if merged).
Expected: one ref line (non-empty). If empty, STOP — push the `sf-template` branch first (Tasks 1–2 commits included).

- [ ] **Step 2: Update `.gitmodules` branch**

In `.gitmodules`, change the `.template` submodule `branch`:

```ini
[submodule ".template"]
	path = .template
	url = https://github.com/nickmorozov/sf-template
	branch = <SF_TEMPLATE_REF>
```

(If `<SF_TEMPLATE_REF>` is `main` because the enriched template was merged, leave `branch = main` — the point is the pin now resolves to the enriched commit.)

- [ ] **Step 3: Sync the submodule to the enriched ref**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git submodule sync
git submodule update --init --remote --recursive .template
```

- [ ] **Step 4: Verify the enriched template is present**

Run: `cd /Users/nick/Projects/Job/sf-project-template && test -f .template/scripts/node/config.js && test -f .template/scripts/node/backup-audit.js && node .template/scripts/node/config.js deployMode`
Expected: prints `source` (confirms the enriched `sf-template` with `deployMode` + `backup-audit.js` is pinned).

- [ ] **Step 5: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .gitmodules .template
git commit -m "chore: re-pin .template to enriched sf-template (deployMode, backup-audit, scripts)"
```

---

## Task 13: Docs — `README-CI.md`, `SCRIPTS.md`, `MANUAL.md`, ADR seed

Author fresh, org-neutral docs (the cgpm/bumble stock docs describe a different/older setup, so rewrite rather than vendor — except MANUAL.md, which vendors bumble's structure neutralized).

**Files:**

- Create: `docs/README-CI.md`
- Create: `docs/SCRIPTS.md`
- Create: `docs/MANUAL.md`
- Create: `docs/adr/README.md`
- Create: `docs/adr/0001-record-architecture-decisions.md`

- [ ] **Step 1: Create `docs/README-CI.md`**

```markdown
# CI/CD Pipeline

GitHub Actions workflows live in `.github/workflows/` (they cannot run from the `.template/` submodule). The pipeline is **config-driven**: `config/project.config.json` `deployMode` selects the deploy engine.

## Pipeline

Default branch flow (the `pipeline` array in `config/project.config.json`): `dev → qa → uat → main`.

| Branch                   | Workflow          | Source mode                    | Package mode                           |
| ------------------------ | ----------------- | ------------------------------ | -------------------------------------- |
| any PR → dev/qa/uat/main | `validate-pr.yml` | LWC Jest + aer + delta dry-run | same                                   |
| push `dev`               | `deploy-dev.yml`  | delta deploy to DEV            | beta build (canary, no install)        |
| push `qa`                | `deploy-qa.yml`   | delta deploy to QA             | beta build + install QA                |
| push `uat`               | `deploy-uat.yml`  | delta deploy to UAT            | beta build + install UAT               |
| push `main`              | `deploy-prod.yml` | delta deploy to PROD           | release build + promote + install PROD |

After a successful prod deploy, `deploy-prod.yml` forward-merges `main → qa → dev`.

Reusable engines: `sf-deploy-source.yml` (sfdx-git-delta), `sf-deploy-package.yml` (2GP). Reusable gates/notifiers: `admin-guard.yml`, `slack-notify.yml`.

Add-ons: `code-analyzer.yml` (PR static analysis), `stale-branches.yml` (weekday cron), `sf-backup.yml` + `backup-sandboxes.yml` (weekday cron sandbox backups), `claude.yml` + `claude-code-review.yml`.

## Required secrets & variables

Set **repository** secrets:

| Secret                    | Used by        | Notes                                                                     |
| ------------------------- | -------------- | ------------------------------------------------------------------------- |
| `AER_LICENSE_KEY`         | `validate-pr`  | octoberswimmer aer license (Apex tests without an org)                    |
| `SLACK_BOT_TOKEN`         | `slack-notify` | Slack app bot token (`chat:write`, `pins:read/write`, `channels:history`) |
| `SLACK_CHANNEL_ID`        | `slack-notify` | target channel ID                                                         |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude*`      | Claude Code GitHub app token                                              |

Set **per-environment** secrets (GitHub → Settings → Environments → `dev`/`qa`/`uat`/`prod`):

| Secret            | Mode    | Notes                                                  |
| ----------------- | ------- | ------------------------------------------------------ |
| `SFDX_AUTH_URL`   | source  | sfdx auth URL for that env's org                       |
| `DEVHUB_AUTH_URL` | package | sfdx auth URL for the Dev Hub (same value across envs) |
| `ORG_AUTH_URL`    | package | sfdx auth URL for that env's target org                |

Generate an auth URL: `sf org display --verbose --target-org <alias>` → copy `Sfdx Auth Url`.

Optional repository/environment **variables** (flags): `SKIP_DEPLOY`, `SKIP_DATA`, `SKIP_NOTIFY`, `SKIP_VALIDATION`, `FULL_DEPLOY`, `FULL_DATA`, `DELETE_OLD_DATA`, `SF_WAIT_TIMEOUT`.

## Config files

- `config/repo-admins.json` — GitHub logins allowed to push directly to protected branches (admin-guard) and tagged for review (slack-notify). Seed it with your team.
- `config/slack-users.json` — GitHub login → Slack member ID map (so notifications @-mention the right person).

## Branch protection

Require `validate-pr` to pass before merging into `dev`/`qa`/`uat`/`main`. The `admin-guard` job emulates protection on direct pushes (allows repo-admins or merged-PR commits).
```

- [ ] **Step 2: Create `docs/SCRIPTS.md`**

```markdown
# npm Scripts

Cheat-sheet of the common scripts. Template-managed scripts (lint, test, prettier, source:push/pull, data:_, promote:_, sync:\*) are provided by `sf-template` via `sync.js`; the families below are scaffold-owned.

## Source

`npm run source:push` · `npm run source:pull` · `npm run source:diff`
`npm run source:push:force` · `npm run source:pull:force`
`npm run source:sync` · `npm run source:sync:force`
`npm run source:compile` · `npm run source:validate`

## Package (2GP — deployMode: package)

`npm run package:build:beta` · `npm run package:build` (release)
`npm run package:promote`
`npm run package:install:qa` · `:uat` · `:prod` · `:all`
`npm run package:deploy:patch` · `:minor` · `:major`

## Org

`npm run org:auth` · `npm run org:create` · `npm run org:init` · `npm run org:delete`
`npm run org:open` (scratch) · `:dev` · `:qa` · `:uat` · `:prod`
`npm run access:assign:user` · `:admin` · `:all`
`npm run debug:toggle`
`npm run local:dev:app` · `:site` · `:cmp`

## Pipeline

`npm run promote:dev` · `:qa` · `:uat` · `:main`
`npm run backmerge:from-qa` · `:from-uat` · `:from-main`

## Data (SFDMU)

`npm run data:export` · `npm run data:import` · `npm run data:import:sim`

## Tests

`npm test` (lwc + apex) · `npm run test:all`
`npm run test:lwc` · `:watch` · `:coverage`
`npm run test:apex` · `:suite` · `npm run test:local`

## Maintenance

`npm run sync:update` · `npm run update:latest:check` · `:apply`
`npm run org:config:log:schedule` (`:qa` · `:uat` · `:prod`)
```

- [ ] **Step 3: Create `docs/MANUAL.md`** (vendor bumble's structure, neutralized to the default pipeline envs, generic placeholder items)

```markdown
# Manual Deployment Steps

Steps that must be performed manually before or after each automated deployment.
Update this file as new manual steps are identified. Check items off as completed.

---

## DEV

### Pre-Deployment

- [ ] _No manual steps required_

### Post-Deployment

- [ ] _No manual steps required_

---

## QA

### Pre-Deployment

- [ ] _No manual steps required_

### Post-Deployment

- [ ] _No manual steps required_

---

## UAT

### Pre-Deployment

- [ ] _No manual steps required_

### Post-Deployment

- [ ] _No manual steps required_

---

## PROD

### Pre-Deployment

- [ ] _No manual steps required_

### Post-Deployment

- [ ] _No manual steps required_
```

- [ ] **Step 4: Create `docs/adr/README.md`** (Nygard index — seeded with the meta-ADR; vendor sf-sync's index format)

```markdown
# Architecture Decision Records

Numbered, chronological log of significant architecture/design/business decisions. Format: Michael Nygard (Context / Decision / Status / Consequences). New decisions append; existing ADRs are amended only with status changes (e.g. Accepted → Superseded by ADR-NNNN).

## Index

| #                                             | Decision                      | Status   |
| --------------------------------------------- | ----------------------------- | -------- |
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
```

- [ ] **Step 5: Create `docs/adr/0001-record-architecture-decisions.md`** (Nygard's canonical first ADR)

```markdown
# ADR-0001 — Record architecture decisions

**Status:** Accepted
**Date:** _set on first use_

## Context

We need to record the architectural decisions made on this project — the significant ones that shape structure, dependencies, interfaces, or business constraints — so that current and future contributors understand not just _what_ was decided but _why_.

## Decision

We will use Architecture Decision Records, as described by Michael Nygard, stored as Markdown files in `docs/adr/`, named `NNNN-kebab-title.md` (zero-padded, sequential). Each ADR has the sections: Context, Decision, Status, Consequences. The `README.md` in this directory is the index.

## Status

Accepted.

## Consequences

- Decisions are discoverable and reviewable in version control alongside the code.
- Superseding a decision means adding a new ADR and updating the old one's Status to `Superseded by ADR-NNNN` — history is preserved, not rewritten.
- The index in `README.md` must be kept in step with the files on disk.
```

- [ ] **Step 6: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add docs/README-CI.md docs/SCRIPTS.md docs/MANUAL.md docs/adr/
git commit -m "docs: add CI reference, scripts cheat-sheet, manual checklist, ADR seed"
```

---

## Task 14: Postman skeleton (blank values — no committed secrets)

D6 add-on. Ship the directory-format skeleton with **empty cloud IDs and blank env values** (the harvest flagged that bumble's committed `DEV.environment.yaml` contains live secrets — never reproduce that).

**Files:**

- Create: `.postman/resources.yaml`
- Create: `postman/collections/.gitkeep`
- Create: `postman/environments/{dev,qa,uat,prod}.environment.yaml`
- Create: `postman/globals/workspace.globals.yaml`

- [ ] **Step 1: Create `.postman/resources.yaml`**

```yaml
# Postman directory-format sync manifest. Fill in IDs after creating the
# workspace/collection/environments in Postman, or via the Postman VS Code
# extension's "Push to Postman".
workspace:
    id: ''

cloudResources:
    collections: {}
    environments:
        ../postman/environments/dev.environment.yaml: ''
        ../postman/environments/qa.environment.yaml: ''
        ../postman/environments/uat.environment.yaml: ''
        ../postman/environments/prod.environment.yaml: ''
```

- [ ] **Step 2: Create `postman/collections/.gitkeep`** (empty file — preserves the dir for the first collection)

```

```

- [ ] **Step 3: Create the four env files** — `postman/environments/dev.environment.yaml` (repeat for `qa`, `uat`, `prod`, changing only `name:`). **All values blank.**

```yaml
name: DEV
values:
    - key: consumerkey
      value: ''
    - key: consumersecret
      value: ''
    - key: SF username
      value: ''
    - key: SF Password
      value: ''
    - key: Token URL
      value: ''
    - key: Service URL
      value: ''
    - key: token
      value: ''
color: 0
```

(Create `qa.environment.yaml` with `name: QA`, `uat.environment.yaml` with `name: UAT`, `prod.environment.yaml` with `name: PROD` — identical otherwise.)

- [ ] **Step 4: Create `postman/globals/workspace.globals.yaml`**

```yaml
name: Globals
values:
    - key: api
      value: ''
      enabled: true
```

- [ ] **Step 5: Verify no secrets shipped + valid YAML**

```bash
cd /Users/nick/Projects/Job/sf-project-template
grep -rEi 'salesforce\.com|[A-Za-z0-9]{20,}|password.*\S' postman/ .postman/ | grep -v "value: ''" || echo "NO SECRETS"
for f in .postman/resources.yaml postman/environments/dev.environment.yaml postman/globals/workspace.globals.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f')); print('$f OK')"; done
```

Expected: `NO SECRETS`, then `… OK` lines.

- [ ] **Step 6: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add .postman/ postman/
git commit -m "feat(postman): add directory-format skeleton (blank values, no secrets)"
```

---

## Task 15: Scaffold `CLAUDE.md`, `README.md`, `init.zsh` polish

**Files:**

- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `init.zsh`
- Modify: `.gitignore` (ensure `.env` ignored)

- [ ] **Step 1: Replace `CLAUDE.md`** with scaffold guidance documenting the v2 layout, config contract, deployMode, and CI:

````markdown
# CLAUDE.md

Guidance for Claude Code when working in a project scaffolded from `sf-project-template`.

## What this is

An **org-pipeline** Salesforce DX project: `src/main/default/` metadata deployed through a `dev → qa → uat → main` branch pipeline. Shared tooling comes from the `sf-template` submodule at `.template/` (synced by `sync.js`). CI lives in `.github/workflows/` (Actions cannot run from a submodule).

## Org-neutrality contract — `config/project.config.json`

All project/org specifics live here. Keys: `githubOrg`, `projectName`, `aliasPrefix`, `pipeline`, `packageName`, `namespace`, `devHub`, `slackChannel`, **`deployMode`** (`source` | `package`), `aerNamespace`, `aerSkip`. Bash/CI read values via `node scripts/node/config.js <key>`. After `init.zsh`, set `githubOrg`, `deployMode`, and `slackChannel`.

## Deploy modes

- **`source`** (default): CI deploys metadata via `sfdx-git-delta` deltas (`sf-deploy-source.yml`). Per-env secret: `SFDX_AUTH_URL`.
- **`package`**: CI builds a 2GP version on a Dev Hub and installs it (`sf-deploy-package.yml`). Per-env secrets: `DEVHUB_AUTH_URL`, `ORG_AUTH_URL`.

See `docs/README-CI.md` for the full workflow map and required secrets.

## Common commands

```bash
./init.zsh <org-url-or-alias>   # one-time bootstrap
npm run source:push             # deploy to default org
npm run source:pull             # retrieve
npm run test                    # LWC Jest + Apex
npm run sync:update             # pull latest .template + re-apply
npm run promote:qa              # fast-forward dev → qa (etc.)
```
````

Script families (scaffold-owned): `package:*`, `ci:package:*`, `org:{auth,create,init,delete,open:*}`, `access:assign:*`, `local:dev:*`, `source:*`, `backmerge:*`. Template-managed scripts arrive via `sync.js`. See `docs/SCRIPTS.md`.

## Conventions

- Branches: `feature/*` (→ dev) or `hotfix/*` (→ any protected). Protected: `dev`, `qa`, `uat`, `main` — derived from `pipeline`. Conventional Commits.
- Configs (`.prettierrc.yml`, `eslint.config.mjs`, `.husky/*`, `jest.config.js`, etc.) are **template-managed** — edit the `.template/` submodule, not project root.
- 4-space indent, single quotes, 180 width, es5 trailing commas, LF. Apex: no final newline.

````

- [ ] **Step 2: Replace `README.md`** with a quick-start:

```markdown
# PROJECT_NAME

Salesforce DX org-pipeline project, scaffolded from [`sf-project-template`](https://github.com/nickmorozov/sf-project-template).

## Quick start

```bash
gh repo create <org>/<name> --template <org>/sf-project-template --private --clone
cd <name>
./init.zsh <org-url-or-alias>     # substitutes PROJECT_NAME, inits .template, syncs, installs, auths
````

Then in `config/project.config.json` set `githubOrg`, `deployMode` (`source` or `package`), and `slackChannel`, and configure CI secrets (see `docs/README-CI.md`).

## Layout

| Path                 | Purpose                                                    |
| -------------------- | ---------------------------------------------------------- |
| `src/main/default/`  | SFDX-format metadata                                       |
| `.template/`         | shared tooling submodule (`sf-template`)                   |
| `.github/workflows/` | CI pipeline (validate-pr, deploy-\*, backups, claude)      |
| `config/`            | `project.config.json` contract, scratch def, CI registries |
| `docs/`              | `README-CI.md`, `SCRIPTS.md`, `MANUAL.md`, `adr/`          |

See `CLAUDE.md` and `docs/` for details.

````

- [ ] **Step 3: Add a closing hint to `init.zsh`** — in the final "Ready!" box (after the `Next steps:` lines), add a reminder. Insert these two echo lines before the closing `╰───╯` of the final box:

```bash
echo "│    Edit config/project.config.json:     │"
echo "│      githubOrg, deployMode, slackChannel│"
````

(Keep the existing box; this just adds two lines reminding the user to finish wiring the contract.)

- [ ] **Step 4: Ensure `.env` is gitignored**

Run: `cd /Users/nick/Projects/Job/sf-project-template && grep -qxF '.env' .gitignore || printf '\n.env\n' >> .gitignore; grep -n '.env' .gitignore`
Expected: at least one `.env` line in `.gitignore`.

- [ ] **Step 5: Commit**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add CLAUDE.md README.md init.zsh .gitignore
git commit -m "docs: scaffold CLAUDE.md + README quick-start + init.zsh contract hint"
```

---

## Task 16: Validation & scaffold smoke test

Prove the scaffold is internally consistent and the sync layer applies cleanly. Org-dependent steps (auth, `source:validate`) are noted optional — run them if a scratch/sandbox is available.

**Files:** none (verification only).

- [ ] **Step 1: All workflows parse**

```bash
cd /Users/nick/Projects/Job/sf-project-template
for f in .github/workflows/*.yml; do python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1])); print('OK', sys.argv[1])" "$f"; done
```

Expected: one `OK …` per workflow (14 files), no exceptions.

- [ ] **Step 2: actionlint (if available via the synced `.trunk` suite)**

Run: `cd /Users/nick/Projects/Job/sf-project-template && command -v actionlint >/dev/null && actionlint || echo "actionlint not installed — skipping (trunk provides it in CI)"`
Expected: no errors, or the skip message.

- [ ] **Step 3: Reusable `uses:` references resolve**

```bash
cd /Users/nick/Projects/Job/sf-project-template
grep -rhoE 'uses: \./\.github/workflows/[a-z-]+\.yml' .github/workflows | sort -u | sed 's|uses: \./||' | while read -r w; do test -f "$w" && echo "OK $w" || echo "MISSING $w"; done
```

Expected: every referenced reusable (`admin-guard.yml`, `slack-notify.yml`, `sf-deploy-source.yml`, `sf-deploy-package.yml`) prints `OK`. No `MISSING`.

- [ ] **Step 4: Run the init/sync flow (the real bootstrap, minus org auth)**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git submodule update --init --recursive
node .template/sync.js --force
npm install
```

Expected: sync applies template configs/scripts/.claude without error; `npm install` succeeds. Confirm template-managed scripts now exist:

Run: `node -e "const s=require('./package.json').scripts; for (const k of ['lint','test:lwc','source:push','promote:qa','package:bump:patch']) if(!s[k]) throw new Error('missing '+k); console.log('template scripts merged')"`
Expected: `template scripts merged`.

- [ ] **Step 5: Lint + unit tests + node tests**

```bash
cd /Users/nick/Projects/Job/sf-project-template
npm run lint
npm run test:unit
npm run ci:test:node
```

Expected: lint passes (no Aura/LWC JS yet → no errors), `test:unit` passes (`passWithNoTests`), `ci:test:node` runs `node --test scripts/node/*.test.js` green (incl. the `deployMode` test from Task 1, now synced into the project's `scripts/`).

- [ ] **Step 6: Config contract reads**

```bash
cd /Users/nick/Projects/Job/sf-project-template
node scripts/node/config.js deployMode    # → source
node scripts/node/config.js pipeline       # → dev qa uat main
```

- [ ] **Step 7: Drift gate clean**

Run: `cd /Users/nick/Projects/Job/sf-project-template && node .template/sync.js --dry-run`
Expected: reports no pending changes (the scaffold is already in sync with the template — this is the gate CI runs per-PR).

- [ ] **Step 8 (optional, needs an org): source validate**

Run: `npm run source:validate` (dry-run deploy) against an authed default org.
Expected: validation succeeds (empty/initial metadata deploys clean).

- [ ] **Step 9: Final commit (lockfile + any sync-applied changes)**

```bash
cd /Users/nick/Projects/Job/sf-project-template
git add -A
git commit -m "chore: apply sync, lockfile, and validate scaffold" --no-verify
```

---

## Self-Review (run after all tasks)

**1. Spec coverage (Layer B, spec lines 123–132):**

| Spec item                                                                                                                                                                                                                  | Task                                            |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| Re-pin `.template` → enriched `sf-template`                                                                                                                                                                                | Task 12                                         |
| `package.json` families (`package:*`, `ci:package:*`, `org:*`, `access:*`, `local:dev:*`, `test:*`, `source:*`, `promote:*`, `update:latest:*`, `git:commit*`, `org:config:log:schedule*`)                                 | Task 11 (+ sync-managed)                        |
| `config` block → `project.config.json`                                                                                                                                                                                     | Tasks 1, 3, 11                                  |
| CI: `validate-pr`, `build-dev`\*, `deploy-{dev,qa,uat,prod}`, reusable `slack-notify`+`admin-guard`, `sf-deploy` (delta), `stale-branches`, `code-analyzer`, `claude`+`claude-code-review`, `sf-backup`+`backup-sandboxes` | Tasks 4–10 (\*build-dev folded into deploy-dev) |
| docs: `adr/`, `SCRIPTS.md`, `README-CI.md`, `MANUAL.md`                                                                                                                                                                    | Task 13                                         |
| Postman skeleton                                                                                                                                                                                                           | Task 14                                         |
| `config/repo-admins.json` + `config/slack-users.json`                                                                                                                                                                      | Task 3                                          |
| Edge cases: branch guard reads `pipeline` (Plan 1); `force-app` vs `src` (scaffold uses `src`, globs match); aer absent → install-not-vendor (Task 8); packaging without DevHub → fail-fast (Task 6)                       | Tasks 6, 8                                      |

**2. Placeholder scan:** every CI file is either `cp`'d from a named on-disk source + explicit edits, or shown in full. No "TBD"/"add error handling"/"similar to Task N". `PROJECT_NAME` is an intentional init-substituted token, not a plan placeholder.

**3. Type/name consistency:** reusable workflow filenames match every `uses:` (`sf-deploy-source.yml`, `sf-deploy-package.yml`, `admin-guard.yml`, `slack-notify.yml`) — verified mechanically in Task 16 Step 3. `deployMode` values (`source`/`package`) match across config.js, wrappers, and engines. `config.js packageName` output feeds `sf-deploy-package.yml`'s `--package`.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-08-sf-project-template-scaffold.md`.**

Notes before execution:

- **Tasks 1–2 modify `sf-template`** (the synced layer) and **must be pushed** (Prerequisite P1) before Task 12 re-pins. Tasks 3–16 are in `sf-project-template`.
- Tasks are mostly independent but have this order dependency: 1–2 → (3–11 any order) → 12 (needs P1 + the enriched template) → 16 (needs 12's sync).
