# sf-template Foundation Enrichment — Implementation Plan (Plan 1 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the `sf-template` synced layer with the shared, org-neutral tooling that mature consumers (cgpm, enum-manager, bumble-bee) already proved, plus the drift/bug fixes — so every consumer gets it on the next `sync:update`.

**Architecture:** `sf-template` is a git submodule mounted at `<project>/.template/`; `sync.js` copies its configs/scripts/hooks/.claude-kit into the consumer root. This plan adds a `project.config.json` org-neutrality contract + a node config reader that bash scripts consume, relocates the shared `scripts/`, teaches `sync.js` to sync whole directories, ships the `.claude` kit, makes the branch guard + promote pipeline config-driven, and lands the aer install/vendor scripts. CI, packaging, and the `sfdx-project.json` apiVersion bump are explicitly **out of scope** — those belong to the two scaffold plans (Plans 2 & 3) per spec decision D8.

**Tech Stack:** Node 20+ (CommonJS, `node --test`), POSIX/bash shell scripts, git submodules, husky v9, Salesforce CLI.

**Spec:** `docs/superpowers/specs/2026-06-07-sf-dx-template-system-v2-design.md` (Layer A).

**Working repo:** `/Users/nick/Projects/Job/sf-template` (canonical upstream `nickmorozov/sf-template`). All work lands on branch `feature/template-system-v2-spec` (already created; spec already committed there). The pre-commit branch guard blocks `main` — never commit there.

---

## Scope boundary (what this plan does NOT touch)

- No CI workflows (`.github/workflows/`) — `sf-template` is a submodule; Actions can't run from it (D8). Workflows land in the scaffolds (Plans 2 & 3).
- No `sfdx-project.json` / `sourceApiVersion` — `sf-template` is not a deployable SF project; that lives in scaffolds.
- No `package:*` / `org:*` alias-dependent scripts — those depend on the scaffold's alias map; only the alias-agnostic script families that invoke the relocated shell scripts are added here.
- `compile.js` / `auth.js` already exist in `sf-template`. They are NOT blindly replaced; Task 13 diffs them against cgpm's and adopts the better version only if the diff confirms it. Treated as optional polish, not foundational.

---

## File Structure (created/modified in this plan)

**Created in `sf-template`:**

- `config/project.config.json` — org-neutrality contract (default values; scaffold seeds real ones).
- `scripts/node/config.js` + `scripts/node/config.test.js` — JSON config reader for bash + node.
- `scripts/node/bump.js` + `scripts/node/bump.test.js` — dual-file semver bumper (from cgpm).
- `scripts/shell/{run_test_suites,run_aer_suites,full_test,promote,bump_patch,bump_minor,bump_major}.sh` — shared shell tooling.
- `scripts/aer/{install-aer.sh,vendor-aer.sh}` — aer bootstrap (install vs license-gated vendor).
- `scripts/apex/{toggleDebugMode.apex,scheduleLogCleanup.apex}` — generic anonymous-Apex helpers.
- `.editorconfig` — fixes the documented-but-missing config.
- `.worktreeinclude` — worktree bootstrap file list.
- `jest-mocks/lightning/modal.js` — LightningModal mock.
- `.claude/agents/{sf-reviewer,sf-deployer,sf-retriever}.md` — the kit agents (from bumble-bee).
- `.claude/commands/{create-lwc,create-apex,create-flow-apex,deploy,retrieve,run-tests,review,soql,debug,local-dev}.md` — kit commands.
- `.claude/rules/{apex-patterns,lwc-patterns,security,testing}.md` — kit rules.
- `.claude/settings.json` — the 3 documented hooks (authored from CLAUDE.md spec).
- `.trunk/` — meta-linter suite (from cgpm).

**Modified in `sf-template`:**

- `sync.js` — add `COPY_DIRS` recursive sync; add `.worktreeinclude` to `COPY_FILES`; add new `TEMPLATE_MANAGED_SCRIPTS`.
- `.husky/pre-commit` — branch guard reads pipeline from config; add `post-merge` + `pre-merge-commit` hooks.
- `jest.config.js` — add `lightning/modal` moduleNameMapper + worktree/.claude testPathIgnorePatterns.
- `package.json` — add the alias-agnostic managed scripts + `commander` devDep.
- `CLAUDE.md` — update to reflect synced `scripts/`, the config contract, and the now-real `.claude` kit.

---

## Task 1: Org-neutrality config contract + reader

**Files:**

- Create: `config/project.config.json`
- Create: `scripts/node/config.js`
- Test: `scripts/node/config.test.js`

- [ ] **Step 1: Write the failing test**

Create `scripts/node/config.test.js`:

```js
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');

function tmp() {
    return fs.mkdtempSync(path.join(os.tmpdir(), 'cfg-'));
}

describe('config', () => {
    let dir;
    beforeEach(() => {
        dir = tmp();
        fs.mkdirSync(path.join(dir, 'config'));
    });
    afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

    it('returns defaults when no config file exists', () => {
        fs.rmSync(path.join(dir, 'config'), { recursive: true, force: true });
        const { readConfig, DEFAULTS } = require('./config');
        const cfg = readConfig(dir);
        assert.deepStrictEqual(cfg.pipeline, DEFAULTS.pipeline);
        assert.strictEqual(cfg.namespace, '');
    });

    it('file values override defaults, unspecified keys keep defaults', () => {
        fs.writeFileSync(path.join(dir, 'config', 'project.config.json'), JSON.stringify({ namespace: 'enumsync', pipeline: ['dev', 'main'] }));
        const { readConfig } = require('./config');
        const cfg = readConfig(dir);
        assert.strictEqual(cfg.namespace, 'enumsync');
        assert.deepStrictEqual(cfg.pipeline, ['dev', 'main']);
        assert.strictEqual(cfg.projectName, 'PROJECT_NAME'); // default preserved
    });

    it('formatValue joins arrays with spaces', () => {
        const { formatValue } = require('./config');
        assert.strictEqual(formatValue(['dev', 'qa', 'main']), 'dev qa main');
        assert.strictEqual(formatValue('x'), 'x');
        assert.strictEqual(formatValue(undefined), '');
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test scripts/node/config.test.js`
Expected: FAIL — `Cannot find module './config'`.

- [ ] **Step 3: Write the config reader**

Create `scripts/node/config.js`:

```js
//
// scripts/node/config.js
//
// Single source of org/project-specific values. Tracked template files stay
// org-neutral; everything that varies per project/fork lives in
// config/project.config.json. Bash scripts read values via the CLI form:
//   node scripts/node/config.js pipeline   # arrays print space-separated
//
const fs = require('fs');
const path = require('path');

const DEFAULTS = {
    githubOrg: '',
    projectName: 'PROJECT_NAME',
    aliasPrefix: '',
    pipeline: ['dev', 'qa', 'uat', 'main'],
    packageName: 'PROJECT_NAME',
    namespace: '',
    devHub: '',
    slackChannel: '',
    aerNamespace: '',
    aerSkip: [],
};

function readConfig(rootDir = process.cwd()) {
    const file = path.join(rootDir, 'config', 'project.config.json');
    let fileCfg = {};
    if (fs.existsSync(file)) {
        fileCfg = JSON.parse(fs.readFileSync(file, 'utf8'));
    }
    return { ...DEFAULTS, ...fileCfg };
}

function formatValue(v) {
    if (Array.isArray(v)) return v.join(' ');
    if (v === null || v === undefined) return '';
    return String(v);
}

if (require.main === module) {
    const key = process.argv[2];
    const cfg = readConfig();
    if (!key) {
        process.stdout.write(JSON.stringify(cfg, null, 2) + '\n');
    } else {
        process.stdout.write(formatValue(cfg[key]) + '\n');
    }
}

module.exports = { readConfig, formatValue, DEFAULTS };
```

- [ ] **Step 4: Create the default config file**

Create `config/project.config.json`:

```json
{
    "githubOrg": "",
    "projectName": "PROJECT_NAME",
    "aliasPrefix": "",
    "pipeline": ["dev", "qa", "uat", "main"],
    "packageName": "PROJECT_NAME",
    "namespace": "",
    "devHub": "",
    "slackChannel": "",
    "aerNamespace": "",
    "aerSkip": []
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `node --test scripts/node/config.test.js`
Expected: PASS — 3 tests.

- [ ] **Step 6: Verify the CLI form bash will use**

Run: `node scripts/node/config.js pipeline`
Expected output: `dev qa uat main`

- [ ] **Step 7: Commit**

```bash
git add config/project.config.json scripts/node/config.js scripts/node/config.test.js
git commit -m "feat(config): add project.config.json org-neutrality contract + reader"
```

---

## Task 2: Fix the missing `.editorconfig`

**Files:**

- Create: `.editorconfig`

`.editorconfig` is listed in `sync.js` `COPY_FILES` and documented in CLAUDE.md, but the source file does not exist, so the sync silently skips it. Create it with the exact content the consumers already use.

- [ ] **Step 1: Create `.editorconfig`**

```ini
root = true

[*]
insert_final_newline = false
trim_trailing_whitespace = true
end_of_line = lf
indent_style = space
indent_size = 4
max_line_length = 180

[*.{json,yml,yaml}]
indent_size = 2
```

- [ ] **Step 2: Verify it matches the consumer copy**

Run: `diff .editorconfig /Users/nick/Projects/Job/cgpm/.editorconfig`
Expected: no output (identical).

- [ ] **Step 3: Commit**

```bash
git add .editorconfig
git commit -m "fix(sync): ship .editorconfig (was referenced but missing, silently skipped)"
```

---

## Task 3: Jest modal mock + config mapper

**Files:**

- Create: `jest-mocks/lightning/modal.js`
- Modify: `jest.config.js`

- [ ] **Step 1: Copy the modal mock from enum-manager**

Run:

```bash
mkdir -p jest-mocks/lightning
cp /Users/nick/Projects/Enum/enum-manager/jest-mocks/lightning/modal.js jest-mocks/lightning/modal.js
```

- [ ] **Step 2: Replace `jest.config.js` with the mapper-aware version**

Overwrite `jest.config.js` with:

```js
const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        ...jestConfig.moduleNameMapper,
        '^lightning/modal$': '<rootDir>/jest-mocks/lightning/modal',
    },
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/.worktrees/', '<rootDir>/.claude/'],
    testEnvironment: 'node',
    testMatch: ['**/lwc/*/__tests__/*.test.js'],
    collectCoverage: true,
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov'],
    passWithNoTests: true,
};
```

- [ ] **Step 3: Verify config parses**

Run: `node -e "require('./jest.config.js'); console.log('ok')"`
Expected: `ok` (no throw).

- [ ] **Step 4: Commit**

```bash
git add jest-mocks/lightning/modal.js jest.config.js
git commit -m "feat(jest): add lightning/modal mock + worktree/.claude ignore patterns"
```

---

## Task 4: Worktree include file

**Files:**

- Create: `.worktreeinclude`

- [ ] **Step 1: Create `.worktreeinclude`**

```
.idea
.illuminatedCloud
node_modules
.sf
.sfdx
.env
.claude
```

- [ ] **Step 2: Commit**

```bash
git add .worktreeinclude
git commit -m "feat: add .worktreeinclude (carry untracked dirs into git worktrees)"
```

---

## Task 5: Relocate the semver bumper (bump.js + tests)

**Files:**

- Create: `scripts/node/bump.js`
- Test: `scripts/node/bump.test.js`

`bump.js` writes the new version into both `package.json` and `sfdx-project.json` (`versionNumber: x.y.z.NEXT`). The test is hermetic (creates its own temp dirs), so it runs unchanged in `sf-template` even though `sf-template` has no `sfdx-project.json`.

- [ ] **Step 1: Copy bump.js and its test from cgpm**

Run:

```bash
cp /Users/nick/Projects/Job/cgpm/scripts/node/bump.js scripts/node/bump.js
cp /Users/nick/Projects/Job/cgpm/scripts/node/bump.test.js scripts/node/bump.test.js
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `node --test scripts/node/bump.test.js`
Expected: PASS — 5 tests (patch/minor/major/preserve-fields/reject-invalid).

- [ ] **Step 3: Commit**

```bash
git add scripts/node/bump.js scripts/node/bump.test.js
git commit -m "feat(scripts): relocate dual-file semver bumper from cgpm (with tests)"
```

---

## Task 6: Relocate generic shell scripts (verbatim)

**Files:**

- Create: `scripts/shell/{run_test_suites.sh,full_test.sh,bump_patch.sh,bump_minor.sh,bump_major.sh}`

These are byte-identical in cgpm and enum-manager and contain no project-specific values, so they copy verbatim. (`promote.sh` and `run_aer_suites.sh` need transformation — Tasks 7 & 8.)

- [ ] **Step 1: Copy the verbatim shell scripts**

Run:

```bash
mkdir -p scripts/shell
for f in run_test_suites.sh full_test.sh bump_patch.sh bump_minor.sh bump_major.sh; do
  cp "/Users/nick/Projects/Job/cgpm/scripts/shell/$f" "scripts/shell/$f"
done
chmod +x scripts/shell/*.sh
```

- [ ] **Step 2: Syntax-check each script**

Run: `for f in scripts/shell/*.sh; do bash -n "$f" && echo "ok: $f"; done`
Expected: `ok:` for each of the 5 files, no syntax errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/shell/run_test_suites.sh scripts/shell/full_test.sh scripts/shell/bump_patch.sh scripts/shell/bump_minor.sh scripts/shell/bump_major.sh
git commit -m "feat(scripts): relocate shared shell tooling (test runner, full_test, bump wrappers)"
```

---

## Task 7: Make `promote.sh` pipeline config-driven

**Files:**

- Create: `scripts/shell/promote.sh` (copy then transform)

cgpm's `promote.sh` hardcodes `PIPELINE=(dev qa main)`. Make it read the `pipeline` array from `project.config.json` (via `config.js`), falling back to the default when the config or node is unavailable.

- [ ] **Step 1: Copy promote.sh from cgpm**

Run: `cp /Users/nick/Projects/Job/cgpm/scripts/shell/promote.sh scripts/shell/promote.sh`

- [ ] **Step 2: Replace the hardcoded PIPELINE line**

In `scripts/shell/promote.sh`, find:

```bash
set -euo pipefail

PIPELINE=(dev qa main)
```

Replace with:

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pipeline branches come from config/project.config.json (org-neutral).
# Fallback keeps the script usable before the config is seeded.
PIPELINE_STR=""
if command -v node >/dev/null 2>&1; then
    PIPELINE_STR="$(node "$SCRIPT_DIR/../node/config.js" pipeline 2>/dev/null || true)"
fi
[ -z "$PIPELINE_STR" ] && PIPELINE_STR="dev qa uat main"
read -r -a PIPELINE <<< "$PIPELINE_STR"
```

- [ ] **Step 3: Syntax-check**

Run: `bash -n scripts/shell/promote.sh && echo ok`
Expected: `ok`.

- [ ] **Step 4: Verify it reads the configured pipeline**

Run (from `sf-template`, which has `config/project.config.json` with the default pipeline):

```bash
bash -c 'source <(sed -n "1,15p" scripts/shell/promote.sh); echo "PIPELINE=${PIPELINE[*]}"' 2>/dev/null || \
node scripts/node/config.js pipeline
```

Expected: prints `dev qa uat main` (the configured default).

- [ ] **Step 5: Commit**

```bash
git add scripts/shell/promote.sh
git commit -m "feat(scripts): promote.sh reads branch pipeline from project.config.json"
```

---

## Task 8: Make `run_aer_suites.sh` namespace/skip config-driven

**Files:**

- Create: `scripts/shell/run_aer_suites.sh` (copy then transform)

cgpm's version hardcodes `--default-namespace cgpm` and a cgpm-test-specific `--skip` list. Read `aerNamespace` and `aerSkip` from config so the harness is reusable; the per-project skip list lives in `project.config.json`.

- [ ] **Step 1: Copy run_aer_suites.sh from cgpm**

Run: `cp /Users/nick/Projects/Job/cgpm/scripts/shell/run_aer_suites.sh scripts/shell/run_aer_suites.sh`

- [ ] **Step 2: Add SCRIPT_DIR + config reads after `set -euo pipefail`**

Find:

```bash
set -euo pipefail

SUITES_DIR="src/test/suites"
```

Replace with:

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUITES_DIR="src/test/suites"

# Namespace + skip-list are project-specific → read from config/project.config.json.
AER_NAMESPACE=""
SKIP_ARGS=()
if command -v node >/dev/null 2>&1; then
    AER_NAMESPACE="$(node "$SCRIPT_DIR/../node/config.js" aerNamespace 2>/dev/null || true)"
    while IFS= read -r _t; do
        [ -n "$_t" ] && SKIP_ARGS+=(--skip "$_t")
    done < <(node "$SCRIPT_DIR/../node/config.js" aerSkip 2>/dev/null | tr ' ' '\n')
fi
NS_ARGS=()
[ -n "$AER_NAMESPACE" ] && NS_ARGS=(--default-namespace "$AER_NAMESPACE")
```

- [ ] **Step 3: Replace the hardcoded aer invocation**

Find the whole block from `# Skip tests incompatible with aer runtime:` through the closing `--filter-path "$SUITE_PATH" src; then` (the `if aer test ... --skip ... --filter-path "$SUITE_PATH" src; then`). Replace the entire `if aer test ... ; then` condition with:

```bash
    echo "─── Suite: $SUITE ($SUITE_PATH) ───"
    if aer test "${NS_ARGS[@]}" -p Admin -p User "${SKIP_ARGS[@]}" --filter-path "$SUITE_PATH" src; then
```

(Delete the cgpm-specific comment block and all the inline `--skip "cgpm.*"` lines — those now come from `aerSkip` in config.)

- [ ] **Step 4: Syntax-check**

Run: `bash -n scripts/shell/run_aer_suites.sh && echo ok`
Expected: `ok`.

- [ ] **Step 5: Commit**

```bash
git add scripts/shell/run_aer_suites.sh
git commit -m "feat(scripts): run_aer_suites.sh reads namespace + skip-list from config"
```

---

## Task 9: aer install + vendor bootstrap scripts

**Files:**

- Create: `scripts/aer/install-aer.sh`
- Create: `scripts/aer/vendor-aer.sh`

aer is license-gated and must not be vendored as a 140 MB LFS binary in the template (D4). Ship a CI/local installer and a separate license-gated vendor escape hatch. `test:local` fails clearly when aer is absent (handled by the runner already erroring on `aer: command not found`; these scripts make the fix discoverable).

- [ ] **Step 1: Create `scripts/aer/install-aer.sh`**

```bash
#!/usr/bin/env bash
#
# install-aer.sh — install the octoberswimmer `aer` local Apex test runner.
# aer is license-gated; this installs the CLI (CI uses octoberswimmer/aer-dist@v1
# with the AER_LICENSE_KEY secret; locally we install via Homebrew or go install).
#
set -euo pipefail

if command -v aer >/dev/null 2>&1; then
    echo "aer already installed: $(command -v aer)"
    exit 0
fi

echo "Installing aer..."
if command -v brew >/dev/null 2>&1; then
    brew tap octoberswimmer/tap 2>/dev/null || true
    brew install aer || {
        echo "Homebrew install failed. See https://github.com/octoberswimmer/aer for manual install."
        exit 1
    }
elif command -v go >/dev/null 2>&1; then
    go install github.com/octoberswimmer/aer@latest
else
    echo "Need Homebrew or Go to install aer. See https://github.com/octoberswimmer/aer"
    exit 1
fi

echo "Done. aer at: $(command -v aer)"
echo "Set AER_LICENSE_KEY in your environment to activate it."
```

- [ ] **Step 2: Create `scripts/aer/vendor-aer.sh`**

```bash
#!/usr/bin/env bash
#
# vendor-aer.sh — OPTIONAL. Vendor a prebuilt aer binary into bin/aer for
# offline/CI-cache use. Requires a valid license; the binary is NOT committed
# by the template (add bin/aer to the project's .gitignore unless you use LFS).
#
# Usage: AER_DOWNLOAD_URL=<url> ./scripts/aer/vendor-aer.sh
#
set -euo pipefail

DEST="bin/aer"
URL="${AER_DOWNLOAD_URL:-}"

if [ -z "$URL" ]; then
    echo "Set AER_DOWNLOAD_URL to a licensed aer binary URL."
    echo "aer is license-gated — you cannot use it without a license."
    exit 1
fi

mkdir -p bin
echo "Downloading aer → $DEST ..."
curl -fsSL "$URL" -o "$DEST"
chmod +x "$DEST"
echo "Vendored aer at $DEST. Ensure your AER_LICENSE_KEY is set to use it."
```

- [ ] **Step 3: Make executable + syntax-check**

Run:

```bash
chmod +x scripts/aer/install-aer.sh scripts/aer/vendor-aer.sh
bash -n scripts/aer/install-aer.sh && bash -n scripts/aer/vendor-aer.sh && echo ok
```

Expected: `ok`.

- [ ] **Step 4: Verify vendor script fails clearly without a URL**

Run: `./scripts/aer/vendor-aer.sh; echo "exit=$?"`
Expected: prints the "license-gated" message and `exit=1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/aer/install-aer.sh scripts/aer/vendor-aer.sh
git commit -m "feat(aer): add install (CI/local) + optional license-gated vendor scripts"
```

---

## Task 10: Generic anonymous-Apex helpers + remove project-specific leak

**Files:**

- Create: `scripts/apex/toggleDebugMode.apex`
- Create: `scripts/apex/scheduleLogCleanup.apex`
- Delete: `scripts/apex/delete-tpm-data.apex` (TPM/cgcloud-specific — does not belong in the generic template)
- Delete: `scripts/apex/toggle-debug.apex` (superseded by `toggleDebugMode.apex`)

- [ ] **Step 1: Copy the generic helpers from cgpm**

Run:

```bash
cp /Users/nick/Projects/Job/cgpm/scripts/apex/toggleDebugMode.apex scripts/apex/toggleDebugMode.apex
cp /Users/nick/Projects/Job/cgpm/scripts/apex/scheduleLogCleanup.apex scripts/apex/scheduleLogCleanup.apex
```

- [ ] **Step 2: Remove the project-specific / superseded scripts**

Run:

```bash
git rm scripts/apex/delete-tpm-data.apex scripts/apex/toggle-debug.apex
```

(If `git rm` reports a path not tracked, `rm -f` it instead — the goal is they are gone.)

- [ ] **Step 3: Verify the apex dir now holds only generic helpers**

Run: `ls scripts/apex`
Expected: `copyPermissionSets.apex  scheduleLogCleanup.apex  toggleDebugMode.apex` (copyPermissionSets stays — it is generic).

- [ ] **Step 4: Commit**

```bash
git add scripts/apex/toggleDebugMode.apex scripts/apex/scheduleLogCleanup.apex
git commit -m "feat(scripts): add generic apex helpers; drop TPM-specific delete-tpm-data"
```

---

## Task 11: Ship the `.claude` kit (agents/commands/rules) + author hooks

**Files:**

- Create: `.claude/agents/{sf-reviewer,sf-deployer,sf-retriever}.md`
- Create: `.claude/commands/{create-lwc,create-apex,create-flow-apex,deploy,retrieve,run-tests,review,soql,debug,local-dev}.md`
- Create: `.claude/rules/{apex-patterns,lwc-patterns,security,testing}.md`
- Create: `.claude/settings.json`

The 14 kit files exist verbatim in bumble-bee and are org-neutral SF guidance. `settings.json` (the 3 hooks the CLAUDE.md advertises) exists nowhere and must be authored from the CLAUDE.md spec.

- [ ] **Step 1: Copy the 14 kit files from bumble-bee**

Run:

```bash
mkdir -p .claude/agents .claude/commands .claude/rules
for f in agents/sf-reviewer.md agents/sf-deployer.md agents/sf-retriever.md \
         commands/create-lwc.md commands/create-apex.md commands/create-flow-apex.md \
         commands/deploy.md commands/retrieve.md commands/run-tests.md \
         commands/review.md commands/soql.md commands/debug.md commands/local-dev.md \
         rules/apex-patterns.md rules/lwc-patterns.md rules/security.md rules/testing.md; do
  cp "/Users/nick/Projects/Job/bumble-bee-tpm/.claude/$f" ".claude/$f"
done
```

- [ ] **Step 2: Verify the 17 files (3 agents + 10 commands + 4 rules) are present**

Run: `find .claude/agents .claude/commands .claude/rules -type f | wc -l`
Expected: `17`. The set matches `CLAUDE_MANAGED_FILES` in `sync.js` exactly (these were already referenced there).

- [ ] **Step 3: Author `.claude/settings.json` with the 3 documented hooks**

Create `.claude/settings.json` (these mirror the behaviors the CLAUDE.md already advertises: block destructive commands, warn on SOQL/DML-in-loop + deprecated LWC conditionals, remind about untested/undeployed changes):

```json
{
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Bash",
                "prompt": "Block clearly destructive Salesforce/git commands. If the command contains `sf org delete`, `rm -rf force-app`, `rm -rf src`, or `git push --force`/`git push -f`, refuse and explain the safer alternative. Otherwise allow."
            }
        ],
        "PostToolUse": [
            {
                "matcher": "Edit|Write|MultiEdit",
                "prompt": "If the edited file is Apex (.cls/.trigger), scan for SOQL or DML inside for/while loops and flag governor-limit risk. If it is an LWC template (.html), flag deprecated `if:true`/`if:false` and suggest `lwc:if`/`lwc:else`. Report only real findings; say nothing if clean."
            }
        ],
        "Stop": [
            {
                "matcher": "",
                "prompt": "If Apex classes were added or changed this session without a matching *Test.cls, remind the user. If there are undeployed changes, remind them to run `npm run source:push`. Keep it to one line; skip if nothing applies."
            }
        ]
    }
}
```

- [ ] **Step 4: Validate the JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8')); console.log('valid')"`
Expected: `valid`.

- [ ] **Step 5: Commit**

```bash
git add .claude/agents .claude/commands .claude/rules .claude/settings.json
git commit -m "feat(claude): ship the .claude kit (agents/commands/rules) + author the 3 hooks"
```

---

## Task 12: Branch guard reads pipeline; add post-merge hooks

**Files:**

- Modify: `.husky/pre-commit`
- Create: `.husky/post-merge`
- Create: `.husky/pre-merge-commit`

`restore-org-config.sh` already exists at `scripts/restore-org-config.sh`. The new hooks wire it into merge events (branch→org alias rewrites), matching bumble-bee. The branch guard derives protected branches from the configured pipeline (fixes the hardcoded `uat`).

- [ ] **Step 1: Replace the branch-guard block in `.husky/pre-commit`**

Find:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PROTECTED_BRANCHES="main dev qa uat"
```

Replace with:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Protected branches = the configured pipeline (config/project.config.json).
# Fallback covers projects before the config is seeded.
PROTECTED_BRANCHES=""
if [ -f config/project.config.json ] && command -v node >/dev/null 2>&1; then
    PROTECTED_BRANCHES=$(node scripts/node/config.js pipeline 2>/dev/null || true)
fi
PROTECTED_BRANCHES="${PROTECTED_BRANCHES:-main dev qa uat}"
```

- [ ] **Step 2: Update the stale lint-staged comment**

Find: `# ── Run lint-staged (prettier, eslint, sf scanner) ──`
Replace with: `# ── Run lint-staged (prettier, eslint, code-analyzer) ──`

(The lint-staged tool change itself is Task 14.)

- [ ] **Step 3: Create `.husky/post-merge`**

```bash
# Rewrite branch-specific org aliases after a fast-forward pull/merge.
if [ -f scripts/restore-org-config.sh ]; then
    sh scripts/restore-org-config.sh --no-stage || true
fi
```

- [ ] **Step 4: Create `.husky/pre-merge-commit`**

```bash
# Stage branch-specific org-config into the merge commit.
if [ -f scripts/restore-org-config.sh ]; then
    sh scripts/restore-org-config.sh || true
fi
```

- [ ] **Step 5: Make hooks executable + syntax-check all three**

Run:

```bash
chmod +x .husky/post-merge .husky/pre-merge-commit
for h in .husky/pre-commit .husky/post-merge .husky/pre-merge-commit; do sh -n "$h" && echo "ok: $h"; done
```

Expected: `ok:` for each.

- [ ] **Step 6: Verify the branch guard resolves the pipeline**

Run: `node scripts/node/config.js pipeline`
Expected: `dev qa uat main` — confirms the guard will protect those four branches.

- [ ] **Step 7: Commit**

```bash
git add .husky/pre-commit .husky/post-merge .husky/pre-merge-commit
git commit -m "feat(hooks): pipeline-driven branch guard + post-merge org-config restore"
```

---

## Task 13: Teach `sync.js` to sync directories + new managed scripts

**Files:**

- Modify: `sync.js`

This is the keystone — without it, the relocated `scripts/`, `jest-mocks/`, `.trunk/` never reach consumers. Add a `COPY_DIRS` recursive sync (binary-safe, additive — never deletes consumer extras, preserves `.sh` exec bit), add `.worktreeinclude` to `COPY_FILES`, and register the new alias-agnostic managed scripts.

- [ ] **Step 1: Add `.worktreeinclude` to `COPY_FILES`**

Find:

```js
const COPY_FILES = ['.prettierrc.yml', '.editorconfig', '.npmrc', '.prettierignore', '.stylelintrc.json', 'eslint.config.mjs', 'jest.config.js', '.mcp.json'];
```

Replace with:

```js
const COPY_FILES = ['.prettierrc.yml', '.editorconfig', '.npmrc', '.prettierignore', '.stylelintrc.json', 'eslint.config.mjs', 'jest.config.js', '.mcp.json', '.worktreeinclude'];

// Whole directories synced recursively (additive: consumer extras are preserved).
const COPY_DIRS = ['scripts', 'jest-mocks', '.trunk'];
```

- [ ] **Step 2: Add the new managed scripts to `TEMPLATE_MANAGED_SCRIPTS`**

In the `TEMPLATE_MANAGED_SCRIPTS` array, after the existing `'data:import:sim',` line and before the closing `];`, add:

```js
    'test:apex',
    'test:apex:suite',
    'test:local',
    'test:local:suite',
    'test:lwc',
    'source:compile',
    'promote',
    'promote:dev',
    'promote:qa',
    'promote:uat',
    'promote:main',
    'package:bump:patch',
    'package:bump:minor',
    'package:bump:major',
```

- [ ] **Step 3: Add the `syncCopyDirs` function**

Immediately after the `syncCopyFiles()` function (after its closing `}` near line 153), add:

```js
// ── Copy whole directories (recursive, binary-safe, additive) ───────

function copyDirRecursive(srcDir, destDir, relBase) {
    for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
        const srcPath = path.join(srcDir, entry.name);
        const destPath = path.join(destDir, entry.name);
        const rel = path.join(relBase, entry.name);

        if (entry.isDirectory()) {
            copyDirRecursive(srcPath, destPath, rel);
            continue;
        }

        const srcContent = fs.readFileSync(srcPath);
        const destExists = fs.existsSync(destPath);
        if (destExists && fs.readFileSync(destPath).equals(srcContent)) continue;

        reportCopy(rel, !destExists);
        if (!DRY_RUN) {
            if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
            fs.writeFileSync(destPath, srcContent);
            if (entry.name.endsWith('.sh')) fs.chmodSync(destPath, 0o755);
        }
    }
}

function syncCopyDirs() {
    for (const relDir of COPY_DIRS) {
        const srcDir = path.join(TEMPLATE_DIR, relDir);
        if (!fs.existsSync(srcDir)) continue;
        copyDirRecursive(srcDir, path.join(PROJECT_DIR, relDir), relDir);
    }
}
```

- [ ] **Step 4: Call `syncCopyDirs()` in `main()`**

Find:

```js
syncCopyFiles();
syncClaudeSettings();
```

Replace with:

```js
syncCopyFiles();
syncCopyDirs();
syncClaudeSettings();
```

- [ ] **Step 5: Smoke-test `--dry-run` against a real consumer**

Run:

```bash
node sync.js --dry-run 2>&1 | head -40 || true
```

Note: `sync.js` resolves `PROJECT_DIR` as the parent of the template dir, so running it directly from `sf-template` targets `Job/`. This is only a parse/smoke check — confirm it runs without throwing and lists `scripts/...` copy lines. Expected: no exception; output includes `+ scripts/node/config.js` etc. (Do NOT run without `--dry-run` here.)

- [ ] **Step 6: Verify the file still parses**

Run: `node -c sync.js && echo "syntax ok"`
Expected: `syntax ok`.

- [ ] **Step 7: Commit**

```bash
git add sync.js
git commit -m "feat(sync): recursively sync scripts/jest-mocks/.trunk + register new managed scripts"
```

---

## Task 14: Modernize lint-staged + package.json scripts/deps

**Files:**

- Modify: `package.json`

Add the alias-agnostic script entries that invoke the relocated shell scripts, switch the Apex scan from the deprecated `sf scanner run` to `sf code-analyzer run`, drop the now-unused `@salesforce/sfdx-scanner` devDep, and add `commander` (used by `auth.js`).

- [ ] **Step 1: Switch the lint-staged Apex scanner**

In `package.json` `lint-staged`, find:

```json
        "**/*.{cls,trigger,page,component}": [
            "sf scanner run"
        ]
```

Replace with:

```json
        "**/*.{cls,trigger,page,component}": [
            "sf code-analyzer run --workspace"
        ]
```

- [ ] **Step 2: Add the new managed script entries**

In `package.json` `scripts`, after the `"data:import:sim"` line, add:

```json
        "test:apex": "bash scripts/shell/run_test_suites.sh",
        "test:apex:suite": "bash scripts/shell/run_test_suites.sh --suite",
        "test:local": "bash scripts/shell/run_aer_suites.sh",
        "test:local:suite": "bash scripts/shell/run_aer_suites.sh --suite",
        "test:lwc": "sfdx-lwc-jest",
        "source:compile": "node scripts/node/compile.js",
        "promote": "bash scripts/shell/promote.sh",
        "promote:dev": "bash scripts/shell/promote.sh dev",
        "promote:qa": "bash scripts/shell/promote.sh qa",
        "promote:uat": "bash scripts/shell/promote.sh uat",
        "promote:main": "bash scripts/shell/promote.sh main",
        "package:bump:patch": "bash scripts/shell/bump_patch.sh",
        "package:bump:minor": "bash scripts/shell/bump_minor.sh",
        "package:bump:major": "bash scripts/shell/bump_major.sh",
```

- [ ] **Step 3: Drop `@salesforce/sfdx-scanner`, add `commander`**

In `devDependencies`, remove the line:

```json
        "@salesforce/sfdx-scanner": "^4.12.0",
```

and add (keep alphabetical order — `commander` sorts after `@`-scoped packages):

```json
        "commander": "^12.1.0",
```

- [ ] **Step 4: Validate package.json**

Run: `node -e "JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('valid')"`
Expected: `valid`.

- [ ] **Step 5: Commit**

```bash
git add package.json
git commit -m "feat(pkg): code-analyzer lint-staged, add test/promote/bump scripts, +commander -sfdx-scanner"
```

---

## Task 15: Ship the `.trunk` meta-linter suite

**Files:**

- Create: `.trunk/` (copied from cgpm)

- [ ] **Step 1: Copy the `.trunk` directory from cgpm**

Run:

```bash
cp -R /Users/nick/Projects/Job/cgpm/.trunk .trunk
```

- [ ] **Step 2: Verify the trunk config is present**

Run: `ls .trunk && test -f .trunk/trunk.yaml && echo "trunk.yaml present"`
Expected: lists the trunk contents and prints `trunk.yaml present`.

- [ ] **Step 3: Commit**

```bash
git add .trunk
git commit -m "feat(lint): ship .trunk meta-linter suite (trufflehog/checkov/osv-scanner/actionlint)"
```

---

## Task 16: Update `sf-template` CLAUDE.md to match the new reality

**Files:**

- Modify: `CLAUDE.md`

The CLAUDE.md currently says CI workflows + `post-merge`/`restore-org-config.sh` are NOT included, and described the `.claude` kit as aspirational. Update the "What This Template Does NOT Include" section and the config-files table to reflect synced `scripts/`, the `project.config.json` contract, the now-shipped `.claude` kit/hooks, and the new managed scripts.

- [ ] **Step 1: Update the "What This Template Does NOT Include" list**

Find:

```markdown
- `post-merge` / `restore-org-config.sh` hooks (multi-org branch config)
- CI/CD workflows (`.github/workflows/`)
```

Replace with:

```markdown
- CI/CD workflows (`.github/workflows/`) — these live in the scaffold repos (sf-project-template / sf-package-template), not here; GitHub Actions cannot run from a submodule.
```

(`post-merge`/`restore-org-config.sh` are now synced — remove that line.)

- [ ] **Step 2: Add a "Synced directories & config contract" subsection**

After the "Config Files" table in the Architecture section, add:

```markdown
### Synced Directories

`sync.js` also copies these directories into the consumer (additive — your project-specific files are preserved):

| Directory     | Contents                                                                                                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `scripts/`    | `node/` (config reader, semver bumper, compile, auth), `shell/` (suite runners, promote, full_test, bump wrappers), `aer/` (install + vendor), `apex/` (generic helpers) |
| `jest-mocks/` | `lightning/modal.js` (wired via `jest.config.js` `moduleNameMapper`)                                                                                                     |
| `.trunk/`     | meta-linter suite (security/IaC/secret scanning)                                                                                                                         |

### Org-Neutrality Contract (`config/project.config.json`)

All org/project-specific values live in one file so the template stays org-neutral and forks cleanly. Keys: `githubOrg`, `projectName`, `aliasPrefix`, `pipeline` (branch array — drives the branch guard and `promote.sh`), `packageName`, `namespace`, `devHub`, `slackChannel`, `aerNamespace`, `aerSkip`. Read by bash via `node scripts/node/config.js <key>`.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): document synced scripts/, config contract, shipped .claude kit"
```

---

## Task 17: Full-template validation

**Files:** none (verification only)

- [ ] **Step 1: Run all node tests**

Run: `node --test scripts/node/`
Expected: PASS — config (3) + bump (5) = 8 tests, 0 failures.

- [ ] **Step 2: Syntax-check every shell script and hook**

Run:

```bash
for f in scripts/shell/*.sh scripts/aer/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
for h in .husky/pre-commit .husky/post-merge .husky/pre-merge-commit; do sh -n "$h" || echo "FAIL: $h"; done
echo "syntax check done"
```

Expected: `syntax check done` with no `FAIL:` lines.

- [ ] **Step 3: Validate all JSON configs**

Run:

```bash
for j in package.json config/project.config.json .claude/settings.json; do node -e "JSON.parse(require('fs').readFileSync('$j','utf8'))" && echo "ok: $j"; done
```

Expected: `ok:` for all three.

- [ ] **Step 4: Confirm `sync.js` dry-run lists the new directories**

Run: `node sync.js --dry-run 2>&1 | grep -E 'scripts/|jest-mocks/|\.trunk/|\.editorconfig|\.worktreeinclude' | head`
Expected: lines showing `scripts/...`, `jest-mocks/lightning/modal.js`, `.trunk/...`, `.editorconfig`, `.worktreeinclude` would be copied (proves the keystone works end-to-end).

- [ ] **Step 5: Push the branch**

```bash
git push -u origin feature/template-system-v2-spec
```

- [ ] **Step 6: Hand off to scaffold plans**

Plan 1 complete. The enriched `sf-template` is now an independently shippable foundation: any consumer running `npm run sync:update` gets the new `scripts/`, configs, `.claude` kit, and config-driven hooks. Next: Plan 2 (`sf-project-template` org-pipeline scaffold) and Plan 3 (`sf-package-template` managed-package scaffold), both written against this frozen contract, then Plan 4 (fork into `corraogroup` + `enum-labs`).

---

## Self-Review

**Spec coverage (Layer A items):**

- scripts/node (compile, auth, bump, backup-audit) → Tasks 5, 13, 14; `backup-audit.js` deferred to the scaffold backup workflow (Plan 2) since it's only invoked by `sf-backup.yml` (CI, which is scaffold-layer). ✎ Noted as a deliberate deferral, not a gap.
- scripts/shell (all) → Tasks 6, 7, 8. ✓
- aer install + vendor → Task 9. ✓
- jest config + mock → Task 3. ✓
- `.ncurc.json`, `.worktreeinclude`, `.editorconfig`, `.trunk` → Tasks 2, 4, 15 (`.ncurc.json` already present in `sf-template` — no task needed). ✓
- pipeline-driven branch guard + post-merge hooks → Task 12. ✓
- `.claude` kit + hooks → Task 11. ✓
- modernize lint-staged / drop sfdx-scanner → Task 14. ✓
- sync.js fixes (dir sync, managed scripts) → Task 13. ✓
- `sourceApiVersion 61→62` → **out of scope** (sf-template has no sfdx-project.json; belongs to scaffolds). ✓ fenced.
- `compile.js`/`auth.js` upgrade → Scope boundary note; optional, diff-first. Not a foundational gap.

**Placeholder scan:** No TBD/TODO. Every code step shows full content or an exact `cp`/edit. ✓

**Type/name consistency:** `readConfig`/`formatValue`/`DEFAULTS` exported by `config.js` (Task 1) and consumed identically by promote.sh/run_aer_suites.sh/pre-commit (Tasks 7, 8, 12) via the `node scripts/node/config.js <key>` CLI; `pipeline`/`aerNamespace`/`aerSkip` keys match the `project.config.json` shape and the DEFAULTS object. `COPY_DIRS`/`syncCopyDirs`/`copyDirRecursive` defined and called in Task 13. ✓
