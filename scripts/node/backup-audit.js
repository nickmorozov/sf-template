#!/usr/bin/env node

'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const BACKUP_LOG = path.resolve(__dirname, '../../BACKUP-LOG.csv');
const HEADER = 'timestamp,org,component_type,component_name,action,modified_by,modified_date,created_by,created_date';

// Metadata types queryable via Tooling API with CreatedBy/LastModifiedBy
const TOOLING_TYPES = new Map([
    ['ApexClass', 'ApexClass'],
    ['ApexTrigger', 'ApexTrigger'],
    ['ApexPage', 'ApexPage'],
    ['ApexComponent', 'ApexComponent'],
    ['LightningComponentBundle', 'LightningComponentBundle'],
    ['AuraDefinitionBundle', 'AuraDefinitionBundle'],
    ['Flow', 'Flow'],
    ['FlowDefinition', 'Flow'],
    ['CustomObject', 'EntityDefinition'],
]);

function sfQuery(orgAlias, query, tooling = false) {
    const args = ['data', 'query', '--target-org', orgAlias, '--query', query, '--json'];
    if (tooling) args.push('--use-tooling-api');
    try {
        const raw = execFileSync('sf', args, {
            encoding: 'utf-8',
            timeout: 120_000,
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        return JSON.parse(raw).result?.records || [];
    } catch (err) {
        console.warn(`Query failed: ${query}\n${err.stderr || err.message}`);
        return [];
    }
}

function escapeCsv(value) {
    const str = String(value ?? '');
    return `"${str.replace(/"/g, '""')}"`;
}

function main() {
    const [, , orgAlias, orgName, previewJsonPath] = process.argv;

    if (!orgAlias || !orgName || !previewJsonPath) {
        console.error('Usage: backup-audit.js <org_alias> <org_name> <preview_json_path>');
        process.exit(1);
    }

    const timestamp = new Date().toISOString();

    // ── Parse retrieve preview ──────────────────────────────────────────
    let fileResponses;
    try {
        const preview = JSON.parse(fs.readFileSync(previewJsonPath, 'utf-8'));
        fileResponses = preview.result?.fileResponses || [];
    } catch {
        console.warn('Could not parse retrieve preview JSON. Skipping audit.');
        return;
    }

    if (fileResponses.length === 0) {
        console.log('No changes to audit.');
        return;
    }

    console.log(`Auditing ${fileResponses.length} changed component(s)...`);

    // ── Query SourceMember for changed-by info ──────────────────────────
    const sourceMembers = sfQuery(orgAlias, 'SELECT MemberType, MemberName, ChangedBy, IsNewMember FROM SourceMember WHERE IsNameObsolete = false AND RevisionCounter > 0', true);

    const smMap = new Map();
    const userIds = new Set();
    for (const sm of sourceMembers) {
        smMap.set(`${sm.MemberType}:${sm.MemberName}`, sm);
        if (sm.ChangedBy) userIds.add(sm.ChangedBy);
    }

    // ── Resolve user IDs to display names ───────────────────────────────
    const userMap = new Map();
    if (userIds.size > 0) {
        const idList = [...userIds].map((id) => `'${id}'`).join(',');
        const users = sfQuery(orgAlias, `SELECT Id, Name FROM User WHERE Id IN (${idList})`);
        for (const u of users) userMap.set(u.Id, u.Name);
    }

    // ── Batch-query Tooling API for detailed metadata ───────────────────
    const enrichable = new Map();
    for (const fr of fileResponses) {
        const toolingType = TOOLING_TYPES.get(fr.type);
        if (toolingType) {
            if (!enrichable.has(toolingType)) enrichable.set(toolingType, []);
            enrichable.get(toolingType).push(fr.fullName);
        }
    }

    const detailMap = new Map();
    for (const [toolingType, names] of enrichable) {
        const nameField = toolingType === 'EntityDefinition' ? 'DeveloperName' : 'Name';
        const nameList = names.map((n) => `'${n.replace(/'/g, "\\'")}'`).join(',');

        const records = sfQuery(
            orgAlias,
            `SELECT ${nameField}, CreatedBy.Name, CreatedDate, LastModifiedBy.Name, LastModifiedDate FROM ${toolingType} WHERE ${nameField} IN (${nameList})`,
            true
        );

        for (const r of records) {
            detailMap.set(`${toolingType}:${r[nameField]}`, {
                createdBy: r.CreatedBy?.Name || '',
                createdDate: r.CreatedDate || '',
                modifiedBy: r.LastModifiedBy?.Name || '',
                modifiedDate: r.LastModifiedDate || '',
            });
        }
    }

    // ── Build CSV rows ──────────────────────────────────────────────────
    const rows = [];
    for (const fr of fileResponses) {
        const action = fr.state === 'Add' ? 'Created' : fr.state === 'Delete' ? 'Deleted' : 'Modified';

        const toolingType = TOOLING_TYPES.get(fr.type);
        const detail = toolingType ? detailMap.get(`${toolingType}:${fr.fullName}`) : null;

        const sm = smMap.get(`${fr.type}:${fr.fullName}`);
        const smUserName = sm?.ChangedBy ? userMap.get(sm.ChangedBy) || sm.ChangedBy : '';

        rows.push(
            [timestamp, orgName, fr.type, fr.fullName, action, detail?.modifiedBy || smUserName, detail?.modifiedDate || '', detail?.createdBy || '', detail?.createdDate || '']
                .map(escapeCsv)
                .join(',')
        );
    }

    // ── Append to BACKUP-LOG.csv ────────────────────────────────────────
    const needsHeader = !fs.existsSync(BACKUP_LOG) || fs.statSync(BACKUP_LOG).size === 0;
    const content = (needsHeader ? HEADER + '\n' : '') + rows.join('\n') + '\n';
    fs.appendFileSync(BACKUP_LOG, content);

    console.log(`Appended ${rows.length} row(s) to BACKUP-LOG.csv`);
}

main();
