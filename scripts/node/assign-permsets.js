#!/usr/bin/env node

// Assigns CG_TPM_User and CG_TPM_Developer permission sets to all users
// in config/org-users.json, then copies all other permission sets from the
// first user (source) to the rest.
//
// Usage: node scripts/node/assign-permsets.js [source-username]

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const configPath = path.join(__dirname, '../../config/org-users.json');
const users = JSON.parse(fs.readFileSync(configPath, 'utf8'));

if (users.length === 0) {
    console.log('No users found in config/org-users.json');
    process.exit(1);
}

// 1. Assign named permission sets to all users
const permsets = ['CG_TPM_User', 'CG_TPM_Developer'];

for (const permset of permsets) {
    console.log(`Assigning ${permset}...`);
    try {
        execFileSync('sf', ['org', 'assign', 'permset', '--name', permset, '--on-behalf-of', ...users], {
            stdio: 'inherit'
        });
    } catch (e) {
        console.error(`Failed to assign ${permset}: ${e.message}`);
    }
}

console.log('Permission sets assigned');

// 2. Copy all permission sets from source user to others
if (users.length < 2) {
    process.exit(0);
}

const source = process.argv[2] || users[0];
const targets = users.filter((u) => u !== source);

if (targets.length === 0) {
    process.exit(0);
}

console.log(`\nCopying permission sets: ${source} -> ${targets.join(', ')}`);

const targetList = targets.map((t) => `'${t}'`).join(', ');

const apex = `String SOURCE = '${source}';

for (String TARGET : new List<String>{ ${targetList} }) {
    List<User> u = [
        SELECT Id, Username, Email
        FROM User
        WHERE Username IN :new List<String>{ SOURCE, TARGET }
        ORDER BY IsActive DESC
        LIMIT 2
    ];

    if (u.size() < 2) {
        String username = (u.isEmpty() ? SOURCE + ' and ' + TARGET : (u.size() == 1 && u[0].Username == SOURCE) ? TARGET : SOURCE);
        System.debug(LoggingLevel.ERROR, 'Username not found: ' + username);
        return;
    }

    User src = u[0].Username == SOURCE ? u[0] : u[1];
    User dst = u[0].Username == TARGET ? u[0] : u[1];

    Set<Id> srcPsIds = new Set<Id>();
    Map<Id, PermissionSet> srcPsById = new Map<Id, PermissionSet>(
        [
            SELECT Id, Name, Label, IsOwnedByProfile, LicenseId
            FROM PermissionSet
            WHERE Id IN (SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :src.Id)
        ]
    );
    for (PermissionSet ps : srcPsById.values()) {
        if (!ps.IsOwnedByProfile)
            srcPsIds.add(ps.Id);
    }

    Set<Id> dstPsIds = new Set<Id>();
    for (PermissionSetAssignment psa : [SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :dst.Id]) {
        dstPsIds.add(psa.PermissionSetId);
    }

    List<PermissionSetAssignment> toInsertPSA = new List<PermissionSetAssignment>();
    for (Id psId : srcPsIds) {
        if (!dstPsIds.contains(psId)) {
            toInsertPSA.add(new PermissionSetAssignment(AssigneeId = dst.Id, PermissionSetId = psId));
        }
    }

    Integer psSuccess = 0;
    List<String> psAdded = new List<String>();
    List<String> errors = new List<String>();

    if (!toInsertPSA.isEmpty()) {
        Database.SaveResult[] r = Database.insert(toInsertPSA, false);
        for (Integer i = 0; i < r.size(); i++) {
            if (r[i].isSuccess()) {
                psSuccess++;
                Id psId = toInsertPSA[i].PermissionSetId;
                psAdded.add(srcPsById.containsKey(psId) ? srcPsById.get(psId).Label : String.valueOf(psId));
            } else {
                for (Database.Error e : r[i].getErrors()) {
                    errors.add('PS [' + toInsertPSA[i].PermissionSetId + ']: ' + e.getMessage());
                }
            }
        }
    }

    System.debug(LoggingLevel.INFO, 'Copied from: ' + src.Username + '  ->  to: ' + dst.Username);
    System.debug(LoggingLevel.INFO, 'Permission Sets added: ' + psSuccess + ' ' + psAdded);
    if (!errors.isEmpty()) {
        System.debug(LoggingLevel.WARN, 'Some assignments failed:\\n - ' + String.join(errors, '\\n - '));
    }
}`;

const tmpFile = path.join(os.tmpdir(), 'copy-permission-sets.apex');
fs.writeFileSync(tmpFile, apex);

try {
    execFileSync('sf', ['apex', 'run', '--file', tmpFile], { stdio: 'inherit' });
} finally {
    fs.unlinkSync(tmpFile);
}
