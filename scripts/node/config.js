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
    deployMode: 'source',
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
    } else if (!Object.prototype.hasOwnProperty.call(cfg, key)) {
        process.stderr.write(`Unknown config key: ${key}\n`);
        process.exit(1);
    } else {
        process.stdout.write(formatValue(cfg[key]) + '\n');
    }
}

module.exports = { readConfig, formatValue, DEFAULTS };
