const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { readConfig, formatValue, DEFAULTS } = require('./config');

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
        const cfg = readConfig(dir);
        assert.deepStrictEqual(cfg.pipeline, DEFAULTS.pipeline);
        assert.strictEqual(cfg.namespace, '');
    });

    it('file values override defaults, unspecified keys keep defaults', () => {
        fs.writeFileSync(path.join(dir, 'config', 'project.config.json'), JSON.stringify({ namespace: 'enumsync', pipeline: ['dev', 'main'] }));
        const cfg = readConfig(dir);
        assert.strictEqual(cfg.namespace, 'enumsync');
        assert.deepStrictEqual(cfg.pipeline, ['dev', 'main']);
        assert.strictEqual(cfg.projectName, 'PROJECT_NAME'); // default preserved
    });

    it('formatValue joins arrays with spaces', () => {
        assert.strictEqual(formatValue(['dev', 'qa', 'main']), 'dev qa main');
        assert.strictEqual(formatValue('x'), 'x');
        assert.strictEqual(formatValue(undefined), '');
    });
});
