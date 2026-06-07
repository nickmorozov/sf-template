# Salesforce DX Template System v2 — Design

**Date:** 2026-06-07
**Status:** Approved (design); pending implementation plan
**Author:** Nick (with Claude)
**Spec home:** `nickmorozov/sf-template` (foundation repo of the program)

## Problem

The SF DX template system has two layers today:

- **`sf-template`** — a git submodule mounted as `.template/` in every consumer; `sync.js` continuously copies its configs/scripts into the project. The "living configs" layer.
- **`sf-project-template`** — a GitHub template repo cloned (via `gh repo create --template`) to scaffold a new project. The "initial tree" layer.

Over time the mature consumer projects (`cgpm`, `bumble-bee-tpm`, `enum-manager`, and the newer `sf-sync`) accreted a large amount of reusable tooling that never made it back up into the template:

- Full **scripts/** suites (Tooling-API Apex compile, suite-based test runners, semver bumpers, branch promoters, org-config restore, backup audit).
- Complete **promotion CI pipelines** (validate-PR, build/deploy per env, delta deploys, Slack notify, admin guard, stale-branch reporting, Code Analyzer, Claude bots, scheduled backups).
- A full **packaging lifecycle** (`package:*` / `ci:package:*`).
- **Org lifecycle ergonomics** (`org:create/init/delete/auth`, `access:assign:*`, `local:dev:*`).
- A real **`.claude/` kit** (agents/commands/rules) that `sf-template` _documents and expects but never actually shipped_.
- ISV/2GP **managed-package** setup (namespace, `force-app/` layout, `sf package version create`, ADR-driven decisions) — present only in `sf-sync`, absent from the template entirely.

A fresh scaffold is therefore bare (12 empty metadata dirs, a placeholder `package.json`), while every real project re-derives the same mature setup by hand or by copy-paste from a sibling repo. We want new projects to start mature, and we want one place to maintain the shared tooling.

A second, orthogonal driver: **ownership is splitting.** Job/_ projects are Corrao Group (client) work; Enum/_ projects are the user's own company. The templates currently live under `nickmorozov/*` and serve both. They need to be forked into `corraogroup` and `enum-labs` and allowed to diverge.

## Goals

1. Lift the proven, reusable tooling **up** into the template system, in the correct layer (synced vs scaffold).
2. Introduce a **second scaffold flavor** for ISV/2GP managed-package projects, distinct from the org-pipeline scaffold, both sharing one enriched `sf-template`.
3. Make all three template repos strictly **org-neutral** so they fork cleanly into `corraogroup` and `enum-labs`.
4. Fix the accumulated **drift/bugs** in the current template (documented-but-unshipped `.claude` kit, missing `.editorconfig`, hardcoded branch guard, stale `data` script path, uninitialized nested submodule, scaffold pinned behind upstream).

## Non-Goals

- **Re-pointing existing live consumers** (cgpm, enum-manager, sf-sync, etc.) to the new org forks. Deferred to a separate, carefully-staged migration after the templates are proven. (See Phase 5, explicitly out of scope here.)
- Changing any consumer project's metadata or business logic.
- Building a brand-new data-manager; `sf-data-manager` stays as the nested SFDMU submodule.

## Key Decisions

| #   | Decision                | Choice                                                                                                                                                                                                   |
| --- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D1  | Template shape          | **Two scaffold flavors** (org-pipeline + ISV/managed-package) sharing one enriched `sf-template`.                                                                                                        |
| D2  | Scope of this cycle     | **Whole program, one spec, phased** build in dependency order.                                                                                                                                           |
| D3  | `.claude/` kit          | **Ship & sync** the generic bumble-bee kit (3 agents, 10 commands, 4 rules) via `sf-template`, fulfilling what `sync.js` already documents.                                                              |
| D4  | `aer` local test runner | **Install, don't vendor** (octoberswimmer Action in CI + local bootstrap). Ship an **optional `vendor-aer.sh`** (license-gated) as the escape hatch. No 140 MB LFS binary, no LFS hooks in the template. |
| D5  | Pipeline topology       | **Config-driven**; default `dev → qa → uat → main`. Branch guard + `promote.sh` + CI all read the `pipeline` array (fixes the hardcoded-`uat` bug).                                                      |
| D6  | Default add-ons         | **All on:** ADR docs structure, `.trunk` meta-linter, backup workflow, Postman skeleton.                                                                                                                 |
| D7  | Ownership / forks       | Build org-neutral upstreams under `nickmorozov/*`, then **fork all three into `corraogroup` AND `enum-labs` now**; forks track upstream until they diverge. Ship a `fork-and-repoint.sh`.                |
| D8  | CI location             | CI lives in **scaffold** repos, never in `sf-template`. (GitHub Actions only runs workflows in a repo's own `.github/workflows/`; a submodule's workflows are invisible.)                                |

## Architecture

### Repo topology

```
nickmorozov/sf-template          (UPSTREAM — synced submodule layer)
nickmorozov/sf-project-template  (UPSTREAM — org-pipeline scaffold, enriched)
nickmorozov/sf-package-template  (UPSTREAM — ISV/2GP scaffold, NEW)
        │ fork
        ├── corraogroup/{sf-template, sf-project-template, sf-package-template}   ← Job/* consumers
        └── enum-labs/{sf-template, sf-project-template, sf-package-template}      ← Enum/* consumers
```

9 repos total (3 upstream + 6 forks). Forks sync from upstream via `gh repo sync` until behavior (not just config values) diverges.

> **Open item:** the Enum GitHub org slug. Session memory referenced `enum-solutions-inc`; current `gh` membership shows `enum-labs`. Confirm before forking.

### Layer responsibilities (the synced/scaffold split)

| Concern                                                                                              | Layer                      | Why                                                                                    |
| ---------------------------------------------------------------------------------------------------- | -------------------------- | -------------------------------------------------------------------------------------- |
| Scripts (node/shell/apex), configs, jest, husky hooks, `.claude` kit, aer install                    | **`sf-template`** (synced) | Should keep updating across all consumers via `sync.js`.                               |
| CI workflows, `package.json` script families, packaging config, docs, Postman, `project.config.json` | **scaffolds** (one-time)   | GitHub Actions requires in-repo workflows; project owns/diverges these after scaffold. |

### Org-neutrality contract

No org identity in any tracked template file. All org/project specifics live in **one** committed file, `config/project.config.json`, extending today's `package.json` `config` block:

```jsonc
{
    "githubOrg": "corraogroup", // or enum-labs
    "projectName": "PROJECT_NAME", // substituted by init.zsh
    "aliasPrefix": "cgpm", // org alias scheme: <prefix>-dev, <prefix>-qa, ...
    "pipeline": ["dev", "qa", "uat", "main"],
    "packageName": "PROJECT_NAME",
    "namespace": "", // empty for org-pipeline; set for managed pkg
    "devHub": "", // managed-pkg DevHub alias
    "slackChannel": "",
}
```

Scripts, CI, and hooks read from this file. A fork becomes: fork repo → re-point `.gitmodules` submodule URL → edit this one file. `init.zsh` substitutes `PROJECT_NAME` and seeds the file.

## Components

### Layer A — `sf-template` enrichment (synced)

Source of each item noted; "identical in cgpm+enum-manager" = highest-confidence reuse (already escaped its project verbatim).

- **scripts/node/**
    - `compile.js` — replace template's older copy with the parallel Tooling-API MetadataContainer version (namespace-filtered, structured compiler errors). _(cgpm/enum-manager, identical)_
    - `auth.js` — `sf org login web` URL builder, sandbox/prod aware. Add `commander` to devDeps (currently used transitively).
    - `bump.js` + `bump.test.js` — dual-file (package.json + sfdx-project.json) semver bumper with `node --test` unit tests.
    - `backup-audit.js` — Tooling-API who-changed-what audit writer (backs the backup workflow). _(bumble-bee)_
- **scripts/shell/**
    - `run_test_suites.sh` — discovers `src/test/suites/<name>/`, runs each as a separate `sf apex test run` transaction.
    - `run_aer_suites.sh` — same discovery via local `aer`; per-project skip-list externalized to a config file (not hardcoded).
    - `full_test.sh` — md5 src-hash gate; skip deploy+test when unchanged.
    - `promote.sh` — branch-pipeline fast-forwarder, reads the `pipeline` array, tags `[skip ci]`.
    - `bump_{patch,minor,major}.sh` — clean-tree guard → `bump.js` → commit.
    - `restore-org-config.sh` — rewrites branch→org aliases in protected files (post-merge/pre-merge-commit).
- **scripts/apex/** (generic only): `toggleDebugMode.apex`, `scheduleLogCleanup.apex`.
- **scripts/aer/**: `install-aer.sh` (CI: octoberswimmer Action; local: brew/curl bootstrap) + **`vendor-aer.sh`** (optional, license-gated, pulls the binary on demand).
- **configs**: `jest.config.js` + `jest-mocks/lightning/modal.js` (with `moduleNameMapper`), `.ncurc.json`, `.worktreeinclude`, **`.editorconfig`** (FIX: in `COPY_FILES` but missing from source today), `.trunk/` suite (actionlint, checkov, trufflehog, osv-scanner, shellcheck, ruff, yamllint, markdownlint, …).
- **hooks (synced)**: `pre-commit` (branch guard **derives protected branches from `pipeline`**; profile `<userPermissions>` strip; lint-staged), `post-merge` + `pre-merge-commit` (restore-org-config).
- **.claude/ kit (D3)**: `agents/`(sf-deployer, sf-retriever, sf-reviewer), `commands/`(create-apex, create-flow-apex, create-lwc, debug, deploy, local-dev, retrieve, review, run-tests, soql), `rules/`(apex-patterns, lwc-patterns, testing, security). Wired through `sync.js`'s existing `CLAUDE_MANAGED_FILES`.
- **Modernization**: lint-staged `sf scanner run` → `sf code-analyzer run --workspace`; remove `@salesforce/sfdx-scanner` dep; `sourceApiVersion` 61 → 62; fix the stale "sf scanner" pre-commit comment.
- **sync.js fixes**: consistent `data` script path (`.template/sf-data-manager/src/main.js`); ensure `.editorconfig` ships; reliably init the nested `sf-data-manager` submodule.

### Layer B — `sf-project-template` enrichment (org-pipeline scaffold)

One-time tree for client/org-deploy projects (Corrao archetype). `src/main/default/` layout retained.

- Re-pin `.template` → enriched `sf-template`.
- **package.json**: full script families — `package:*`, `ci:package:*`, `org:{create,init,delete,auth,open:*}`, `access:assign:{admin,user,all}`, `local:dev:{app,site,cmp}`, `test:{apex,apex:suite,local,local:suite,lwc,lwc:*,all}`, `source:{compile,push:force,pull:force,sync,sync:force,diff:push,diff:pull}`, `promote:*`, `update:latest:{check,apply}`, `git:commit{,:force}`, `org:config:log:schedule*`. Plus `config` block (default pipeline `dev→qa→uat→main`, alias map) → migrating to `project.config.json`.
- **CI (in-repo)**: `validate-pr.yml`, `build-dev.yml`, `deploy-{dev,qa,uat,prod}.yml`, reusable `slack-notify.yml` + `admin-guard.yml` (`workflow_call`), `sf-deploy.yml` (delta via sfdx-git-delta, commit markers, env-var gates), `stale-branches.yml`, `code-analyzer.yml`, `claude.yml` + `claude-code-review.yml`, **`sf-backup.yml` + `backup-sandboxes.yml`** (add-on).
- **docs**: `docs/adr/` (Nygard README index), `SCRIPTS.md`, `README-CI.md`, `MANUAL.md` (per-env pre/post-deploy checklist template).
- **Postman skeleton** (add-on): `.postman/resources.yaml` + empty collection + per-env files.
- `config/repo-admins.json` + `config/slack-users.json` templates (consumed by admin-guard / slack-notify).

### Layer C — `sf-package-template` (NEW — ISV/2GP managed-package scaffold)

For sf-sync-style products. `force-app/main/default/` layout + managed-pkg dirs (`certs`, `contentassets`, `customMetadata`, `permissionsets`).

- `.template` → enriched `sf-template`.
- **sfdx-project.json**: package block (`package`, `versionName`, `versionNumber "x.y.z.NEXT"`, `versionDescription`), `namespace` placeholder, `packageAliases` map.
- **package.json packaging scripts**: `package:version:create` (`--code-coverage --installation-key-bypass --wait`), `package:version:promote`, `package:version:list`, `package:version:report`, `package:install` + the shared base scripts.
- **Packaging CI (in-repo)**: on tag/release → `sf package version create` against DevHub (`DEVHUB_AUTH_URL` secret) → Apex tests with coverage (required to promote) → optional promote.
- **Scratch**: namespace-aware `project-scratch-def.json`.
- **init.zsh**: bootstraps the namespace-org + DevHub (PBO) pair, scratch-create + deploy mode (vs the org-pipeline single-org auth flow).
- **Installation key**: gitignored key file + scripting for beta installs.
- **docs/adr/**: pre-seeded ISV decision templates (namespace, packaging type, source-model, pricing) mirroring sf-sync's ADR set.

## Data Flow / Lifecycle

**New org-pipeline project:** `gh repo create <name> --template <org>/sf-project-template` → clone → `./init.zsh <org-url>` → (substitute PROJECT_NAME, seed `project.config.json`, init submodules, `sync.js --force`, `npm install`, self-delete + commit + push, auth org) → mature repo with full CI + scripts.

**New managed-package project:** same, but from `sf-package-template`; init wires DevHub + namespace org, optionally creates a scratch.

**Ongoing:** `npm run sync:update` pulls latest `sf-template` and re-applies configs/scripts/.claude. CI runs `sync.js --dry-run` as a drift gate per-PR.

**Fork (per org):** `fork-and-repoint.sh` → fork the 3 upstreams into the target org, re-point `.gitmodules` URLs, set `githubOrg` in `project.config.json`.

## Error Handling / Edge Cases

- **Branch guard** must read `pipeline` and still allow `ADMIN_OVERRIDE=1` / `--no-verify`.
- **`force-app/` vs `src/`**: lint/prettier/SLDS globs must be layout-aware (sf-sync's hardcoded `"src"` globs silently lint nothing under `force-app/` — fix by reading the source dir from `sfdx-project.json` / config).
- **aer absent**: `run_aer_suites.sh` / `test:local` must fail with a clear "run `vendor-aer.sh` or `install-aer.sh`" message, not a cryptic not-found.
- **Submodule URL drift** after fork: `sync:modules` must respect the re-pointed URL; document that forks edit `.gitmodules`, not just the GitHub fork.
- **Packaging without DevHub**: package CI must fail fast with a clear message if `DEVHUB_AUTH_URL` is unset.

## Testing / Validation

- `node --test` unit tests for new/changed node scripts (follow `bump.test.js`).
- **Scaffold smoke test** per template: clone → `init.zsh` against a scratch → assert `sync.js` applied, `npm run lint`, `npm run test:unit`, and a `source:validate` dry-run all pass; for the package template, assert a `package version create` dry-run resolves.
- `sync.js --dry-run` drift gate wired into scaffold CI.

## Phased Build Plan (one plan, dependency order)

0. **Org-neutrality contract** — define `project.config.json` schema + substitution points; refactor existing `config` block readers.
1. **Enrich `sf-template`** (upstream) — scripts, configs, hooks, `.claude` kit, aer install/vendor, modernization, `sync.js` fixes. Land on a feature branch; smoke-test against a sandbox consumer.
2. **Enrich `sf-project-template`** (upstream) — package.json families, CI suite, docs, Postman, config templates; re-pin `.template`.
3. **Build `sf-package-template`** (upstream, NEW) — force-app layout, packaging config/scripts/CI, namespace init, ADR seed.
4. **Fork** all three → `corraogroup` + `enum-labs`; ship `fork-and-repoint.sh`; verify a fresh scaffold from each org's fork.
5. **(OUT OF SCOPE — separate migration)** Re-point existing live consumers (Job/_ → corraogroup, Enum/_ → enum-labs). Flagged here for completeness only.

## Appendix — Merge-Up Source Map

Where each enriched item came from, and confidence:

| Item                                                                                                                               | Source(s)                              | Confidence             |
| ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- | ---------------------- |
| `scripts/node/{compile,auth,bump,bump.test}.js`                                                                                    | cgpm + enum-manager (identical)        | High                   |
| `scripts/shell/{run_test_suites,run_aer_suites,full_test,promote,bump_*}.sh`                                                       | cgpm + enum-manager (identical)        | High                   |
| `jest.config.js` + `jest-mocks/lightning/modal.js`                                                                                 | cgpm + enum-manager (identical)        | High                   |
| `.ncurc.json`, `.worktreeinclude`, `code-analyzer.yml`                                                                             | cgpm + enum-manager (identical)        | High                   |
| `backup-audit.js`, `sf-backup.yml`, `backup-sandboxes.yml`                                                                         | bumble-bee                             | Med-High               |
| `sf-deploy.yml` (delta), `admin-guard.yml`, `stale-branches.yml`                                                                   | bumble-bee                             | Med-High               |
| `slack-notify.yml` (reusable)                                                                                                      | cgpm + bumble + enum-manager           | High                   |
| Promotion CI (`validate-pr`, `build-dev`, `deploy-*`)                                                                              | cgpm + enum-manager (alias-only diffs) | High                   |
| `package:*` / `ci:package:*` / `org:*` / `access:*` / `local:dev:*` scripts                                                        | cgpm + enum-manager                    | High                   |
| `.claude/` agents+commands+rules                                                                                                   | bumble-bee (generic)                   | High                   |
| `restore-org-config.sh` + post-merge/pre-merge hooks + `.gitattributes merge=ours`                                                 | bumble-bee                             | Med                    |
| `.trunk/` suite                                                                                                                    | cgpm + bumble-bee                      | Med (opt-in by D6: on) |
| Postman skeleton                                                                                                                   | bumble-bee                             | Med (D6: on)           |
| `code-analyzer run` modernization, `ci.yml` drift gate, `sourceApiVersion` 62, ADR structure, `force-app/` layout, packaging needs | sf-sync                                | High                   |

### Bugs/drift to fix (independent of merge-up)

- `.claude/*` documented in `sync.js` + CLAUDE.md but not present → ship (D3).
- `.editorconfig` in `COPY_FILES` but missing from source → add.
- `sf-project-template`'s bundled `.template/` pinned behind upstream → re-pin.
- `data` script path mismatch (`src/main.js` vs `main.js`) → reconcile.
- Branch guard hardcodes `uat` → derive from `pipeline` (D5).
- `sf-data-manager` nested submodule uninitialized in standalone → init in `sync.js`.
