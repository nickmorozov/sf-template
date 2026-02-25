#!/usr/bin/env node
//
// sf-template/sync.js
//
// Syncs template configs from the sf-template submodule to the project root.
// Copies dotfiles verbatim and merges package.json intelligently.
//
// Usage:
//   node sf-template/sync.js             # Preview + apply
//   node sf-template/sync.js --dry-run   # Preview only
//   node sf-template/sync.js --force     # Apply without prompting
//

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { execSync } = require('child_process');

const TEMPLATE_DIR = __dirname;
const PROJECT_DIR = path.resolve(TEMPLATE_DIR, '..');

const DRY_RUN = process.argv.includes('--dry-run');
const FORCE = process.argv.includes('--force');

// ── Files to copy verbatim ──────────────────────────────────────────
const COPY_FILES = ['.prettierrc.yml', '.editorconfig', '.npmrc', '.prettierignore', '.stylelintrc.json', 'eslint.config.mjs', 'jest.config.js'];

const COPY_HOOKS = ['.husky/pre-commit'];

// ── package.json fields managed by the template ─────────────────────
// These are overwritten from the template. Everything else is preserved.
const TEMPLATE_MANAGED_PKG_FIELDS = ['engines', 'lint-staged'];

// Scripts managed by the template (project-specific scripts like open:* are preserved)
const TEMPLATE_MANAGED_SCRIPTS = [
    'lint',
    'lint:slds',
    'lint:slds:fix',
    'test:unit',
    'test:unit:watch',
    'test:unit:debug',
    'test:unit:coverage',
    'prettier',
    'prettier:verify',
    'precommit',
    'prepare',
    'update',
    'source:validate',
    'source:push',
    'source:pull',
    'source:diff',
    'source:reset',
    'org:list',
    'org:open',
    'sync',
    'sync:preview',
    'sync:update',
    'data',
    'data:export',
    'data:export:verbose',
    'data:import',
    'data:import:verbose',
    'data:import:sim',
];

// ── sf-data-manager (nested submodule inside .template) ─────────────
const DATA_MANAGER_WORKSPACE = '.template/sf-data-manager';
const LEGACY_WORKSPACES = ['sf-data-manager', 'data-tool'];

// ── Helpers ──────────────────────────────────────────────────────────

function readJson(filePath) {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function sortKeys(obj) {
    return Object.fromEntries(Object.entries(obj).sort(([a], [b]) => a.localeCompare(b)));
}

function ask(question) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise((resolve) =>
        rl.question(question, (answer) => {
            rl.close();
            resolve(answer);
        })
    );
}

// ── Diff reporting ───────────────────────────────────────────────────

const changes = [];

function reportCopy(relPath, isNew) {
    changes.push({ type: isNew ? 'create' : 'update', file: relPath });
    console.log(`  ${isNew ? '+' : '~'} ${relPath}`);
}

function reportPkgChange(field, detail) {
    changes.push({ type: 'merge', file: 'package.json', field, detail });
    console.log(`  ~ package.json → ${field}: ${detail}`);
}

// ── Copy files ───────────────────────────────────────────────────────

function syncCopyFiles() {
    for (const relPath of [...COPY_FILES, ...COPY_HOOKS]) {
        const src = path.join(TEMPLATE_DIR, relPath);
        const dest = path.join(PROJECT_DIR, relPath);

        if (!fs.existsSync(src)) continue;

        const srcContent = fs.readFileSync(src, 'utf8');
        const destExists = fs.existsSync(dest);
        const destContent = destExists ? fs.readFileSync(dest, 'utf8') : null;

        if (destContent === srcContent) continue; // Already in sync

        reportCopy(relPath, !destExists);

        if (!DRY_RUN) {
            const dir = path.dirname(dest);
            if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
            fs.writeFileSync(dest, srcContent);
            // Preserve executable bit for hooks
            if (relPath.startsWith('.husky/')) {
                fs.chmodSync(dest, 0o755);
            }
        }
    }
}

// ── Merge package.json ───────────────────────────────────────────────

function syncPackageJson() {
    const templatePkgPath = path.join(TEMPLATE_DIR, 'package.json');
    const projectPkgPath = path.join(PROJECT_DIR, 'package.json');

    if (!fs.existsSync(templatePkgPath) || !fs.existsSync(projectPkgPath)) return;

    const tpl = readJson(templatePkgPath);
    const proj = readJson(projectPkgPath);
    const merged = { ...proj };

    // 1. Overwrite template-managed top-level fields
    for (const field of TEMPLATE_MANAGED_PKG_FIELDS) {
        if (tpl[field] && JSON.stringify(proj[field]) !== JSON.stringify(tpl[field])) {
            reportPkgChange(field, 'overwritten from template');
            merged[field] = tpl[field];
        }
    }

    // 2. Merge devDependencies (template versions win, project extras preserved)
    if (tpl.devDependencies) {
        const projDeps = proj.devDependencies || {};
        const mergedDeps = { ...projDeps };
        let depChanges = [];

        for (const [pkg, ver] of Object.entries(tpl.devDependencies)) {
            if (!projDeps[pkg]) {
                depChanges.push(`+${pkg}@${ver}`);
            } else if (projDeps[pkg] !== ver) {
                depChanges.push(`${pkg}: ${projDeps[pkg]} → ${ver}`);
            }
            mergedDeps[pkg] = ver;
        }

        if (depChanges.length > 0) {
            merged.devDependencies = sortKeys(mergedDeps);
            for (const change of depChanges) {
                reportPkgChange('devDependencies', change);
            }
        }
    }

    // 3. Merge scripts (template-managed scripts overwrite, project extras preserved)
    if (tpl.scripts) {
        const projScripts = proj.scripts || {};
        const mergedScripts = { ...projScripts };
        let scriptChanges = [];

        for (const name of TEMPLATE_MANAGED_SCRIPTS) {
            if (!tpl.scripts[name]) continue;

            if (!projScripts[name]) {
                scriptChanges.push(`+${name}`);
            } else if (projScripts[name] !== tpl.scripts[name]) {
                scriptChanges.push(`${name}: updated`);
            } else {
                continue;
            }
            mergedScripts[name] = tpl.scripts[name];
        }

        if (scriptChanges.length > 0) {
            merged.scripts = mergedScripts;
            for (const change of scriptChanges) {
                reportPkgChange('scripts', change);
            }
        }
    }

    // 4. Write if changed
    const projStr = JSON.stringify(proj, null, 4) + '\n';
    const mergedStr = JSON.stringify(merged, null, 4) + '\n';

    if (projStr !== mergedStr && !DRY_RUN) {
        fs.writeFileSync(projectPkgPath, mergedStr);
    }
}

// ── Clean up legacy files ────────────────────────────────────────────

const LEGACY_FILES = ['.huskyrc', '.stylelintrc', 'aura.eslintrc.json', 'lwc.eslint.json', '.eslintrc', '.eslintrc.json', '.eslintignore', 'lint-staged.config.js'];

function cleanLegacy() {
    for (const relPath of LEGACY_FILES) {
        const dest = path.join(PROJECT_DIR, relPath);
        if (fs.existsSync(dest)) {
            console.log(`  - ${relPath} (legacy, superseded)`);
            changes.push({ type: 'delete', file: relPath });
            if (!DRY_RUN) fs.unlinkSync(dest);
        }
    }
}

// ── Fix .gitignore ───────────────────────────────────────────────────

function fixGitignore() {
    const gitignorePath = path.join(PROJECT_DIR, '.gitignore');
    if (!fs.existsSync(gitignorePath)) return;

    let content = fs.readFileSync(gitignorePath, 'utf8');

    // Change ".husky/" to ".husky/_/" so hooks are committed
    if (content.includes('.husky/') && !content.includes('.husky/_/')) {
        const updated = content.replace(/^\.husky\/$/m, '.husky/_/');
        if (updated !== content) {
            reportCopy('.gitignore (.husky/ → .husky/_/)', false);
            if (!DRY_RUN) fs.writeFileSync(gitignorePath, updated);
        }
    }
}

// ── sf-data-manager (nested submodule) + workspace ──────────────────

function syncDataManager() {
    const dmDir = path.join(PROJECT_DIR, DATA_MANAGER_WORKSPACE);

    // 1. Initialize nested submodule if not present
    if (!fs.existsSync(path.join(dmDir, 'main.js'))) {
        console.log(`  + ${DATA_MANAGER_WORKSPACE}/ (init nested submodule)`);
        changes.push({ type: 'create', file: DATA_MANAGER_WORKSPACE });

        if (!DRY_RUN) {
            execSync('git submodule update --init --recursive .template', { cwd: PROJECT_DIR, stdio: 'pipe' });
        }
    }

    // 2. Ensure workspaces includes .template/sf-data-manager
    const projectPkgPath = path.join(PROJECT_DIR, 'package.json');
    if (!fs.existsSync(projectPkgPath)) return;

    const proj = readJson(projectPkgPath);
    const workspaces = proj.workspaces || [];
    let changed = false;

    if (!workspaces.includes(DATA_MANAGER_WORKSPACE)) {
        workspaces.push(DATA_MANAGER_WORKSPACE);
        reportPkgChange('workspaces', `+${DATA_MANAGER_WORKSPACE}`);
        changed = true;
    }

    // 3. Clean up legacy workspace references
    for (const legacy of LEGACY_WORKSPACES) {
        const idx = workspaces.indexOf(legacy);
        if (idx !== -1) {
            workspaces.splice(idx, 1);
            reportPkgChange('workspaces', `-${legacy} (legacy)`);
            changed = true;
        }
    }

    if (changed) {
        proj.workspaces = workspaces;
        if (!DRY_RUN) {
            fs.writeFileSync(projectPkgPath, JSON.stringify(proj, null, 4) + '\n');
        }
    }
}

// ── Main ─────────────────────────────────────────────────────────────

async function main() {
    const templateName = path.basename(TEMPLATE_DIR);
    const projectName = path.basename(PROJECT_DIR);
    console.log(`\nSyncing ${templateName}/ → ${projectName}/\n`);

    syncCopyFiles();
    syncDataManager();
    syncPackageJson();
    cleanLegacy();
    fixGitignore();

    if (changes.length === 0) {
        console.log('  Everything is already in sync.\n');
        return;
    }

    console.log(`\n  ${changes.length} change(s) total.\n`);

    if (DRY_RUN) {
        console.log('  Dry run — no files were modified.\n');
        return;
    }

    if (!FORCE) {
        console.log('  Changes applied. Run "npm install" to update dependencies.\n');
    } else {
        console.log('  Changes applied (--force). Run "npm install" to update dependencies.\n');
    }
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
