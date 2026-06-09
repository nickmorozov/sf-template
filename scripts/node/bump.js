const fs = require('fs');
const path = require('path');

function bump(type, rootDir = process.cwd()) {
    const pkgPath = path.join(rootDir, 'package.json');
    const sfdxPath = path.join(rootDir, 'sfdx-project.json');

    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    const sfdx = JSON.parse(fs.readFileSync(sfdxPath, 'utf8'));

    if (!/^\d+\.\d+\.\d+$/.test(pkg.version)) {
        throw new Error(`Invalid version format in package.json: ${pkg.version}`);
    }
    const [major, minor, patch] = pkg.version.split('.').map(Number);

    let newVersion;
    switch (type) {
        case 'patch':
            newVersion = `${major}.${minor}.${patch + 1}`;
            break;
        case 'minor':
            newVersion = `${major}.${minor + 1}.0`;
            break;
        case 'major':
            newVersion = `${major + 1}.0.0`;
            break;
        default:
            throw new Error(`Unknown bump type: ${type}`);
    }

    pkg.version = newVersion;
    sfdx.packageDirectories[0].versionNumber = `${newVersion}.NEXT`;

    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 4) + '\n');
    fs.writeFileSync(sfdxPath, JSON.stringify(sfdx, null, 2) + '\n');

    return newVersion;
}

if (require.main === module) {
    const type = process.argv[2];
    if (!type || !['patch', 'minor', 'major'].includes(type)) {
        console.error('Usage: node bump.js <patch|minor|major>');
        process.exit(1);
    }
    console.log(bump(type));
}

module.exports = { bump };
