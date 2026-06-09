const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');

const SAMPLE_PKG = { version: '1.18.5' };
const SAMPLE_SFDX = {
    packageDirectories: [{ versionNumber: '1.18.5.NEXT', path: 'src' }],
    namespace: 'cgpm',
};

function setup() {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bump-'));
    fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify(SAMPLE_PKG, null, 4) + '\n');
    fs.writeFileSync(path.join(dir, 'sfdx-project.json'), JSON.stringify(SAMPLE_SFDX, null, 2) + '\n');
    return dir;
}

function readJSON(dir, file) {
    return JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8'));
}

describe('bump', () => {
    let tmpDir;

    beforeEach(() => {
        tmpDir = setup();
    });
    afterEach(() => {
        fs.rmSync(tmpDir, { recursive: true, force: true });
    });

    it('bumps patch: 1.18.5 → 1.18.6', () => {
        const { bump } = require('./bump');
        const version = bump('patch', tmpDir);
        assert.strictEqual(version, '1.18.6');
        assert.strictEqual(readJSON(tmpDir, 'package.json').version, '1.18.6');
        assert.strictEqual(readJSON(tmpDir, 'sfdx-project.json').packageDirectories[0].versionNumber, '1.18.6.NEXT');
    });

    it('bumps minor: 1.18.5 → 1.19.0', () => {
        const { bump } = require('./bump');
        const version = bump('minor', tmpDir);
        assert.strictEqual(version, '1.19.0');
        assert.strictEqual(readJSON(tmpDir, 'package.json').version, '1.19.0');
        assert.strictEqual(readJSON(tmpDir, 'sfdx-project.json').packageDirectories[0].versionNumber, '1.19.0.NEXT');
    });

    it('bumps major: 1.18.5 → 2.0.0', () => {
        const { bump } = require('./bump');
        const version = bump('major', tmpDir);
        assert.strictEqual(version, '2.0.0');
        assert.strictEqual(readJSON(tmpDir, 'package.json').version, '2.0.0');
        assert.strictEqual(readJSON(tmpDir, 'sfdx-project.json').packageDirectories[0].versionNumber, '2.0.0.NEXT');
    });

    it('preserves other fields in both files', () => {
        const { bump } = require('./bump');
        bump('patch', tmpDir);
        const sfdx = readJSON(tmpDir, 'sfdx-project.json');
        assert.strictEqual(sfdx.namespace, 'cgpm');
        assert.strictEqual(sfdx.packageDirectories[0].path, 'src');
    });

    it('rejects invalid bump type', () => {
        const { bump } = require('./bump');
        assert.throws(() => bump('invalid', tmpDir), /Unknown bump type/);
    });
});
