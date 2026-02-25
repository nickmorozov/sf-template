#!/usr/bin/env node

/**
 * Compile all Apex classes and triggers in the target org using the Tooling API.
 *
 * Uses the MetadataContainer → ApexClassMember/ApexTriggerMember → ContainerAsyncRequest flow.
 * This is the programmatic equivalent of Setup → Apex Classes → "Compile all classes".
 *
 * Features:
 *   - Parallel member creation (configurable concurrency, default 10)
 *   - Detailed compiler error reporting with line/column info
 *
 * Usage:
 *   node scripts/node/compilevery time i e.js
 *   node scripts/node/compile.js --target-org myAlias
 */

const { execFileSync, execFile: execFileCb } = require('child_process');
const { readFileSync, writeFileSync, unlinkSync } = require('fs');
const { tmpdir } = require('os');
const { join } = require('path');
const { promisify } = require('util');

const execFileAsync = promisify(execFileCb);

const API_VERSION = '65.0';
const POLL_MS = 2000;
const CONCURRENCY = 10;

const args = process.argv.slice(2);
const orgIdx = args.indexOf('--target-org');
const targetOrg = orgIdx !== -1 ? args[orgIdx + 1] : null;

// Read namespace from sfdx-project.json to filter classes correctly
let namespace = null;
try {
    const project = JSON.parse(readFileSync('sfdx-project.json', 'utf-8'));
    namespace = project.namespace || null;
} catch {}

function namespaceFilter() {
    if (namespace) {
        return `WHERE (NamespacePrefix = '${namespace}' OR NamespacePrefix = null)`;
    }
    return 'WHERE NamespacePrefix = null';
}

// ── Sync CLI helpers (for sequential operations) ──

function sf(sfArgs) {
    try {
        return execFileSync('sf', sfArgs, {
            encoding: 'utf-8',
            maxBuffer: 10 * 1024 * 1024,
            stdio: ['pipe', 'pipe', 'pipe']
        });
    } catch (error) {
        if (error.stdout?.trim()) return error.stdout;
        const msg = error.stderr?.replace(/^Warning:.*\n?/gm, '').trim() || error.message;
        throw new Error(msg);
    }
}

function query(soql) {
    const sfArgs = ['data', 'query', '--query', soql, '--use-tooling-api', '--json'];
    if (targetOrg) sfArgs.push('--target-org', targetOrg);

    const parsed = JSON.parse(sf(sfArgs));
    if (parsed.status !== 0) {
        throw new Error(parsed.message || 'Tooling API query failed');
    }
    return parsed.result.records || [];
}

function rest(endpoint, method = 'GET', body = null) {
    const url = `/services/data/v${API_VERSION}/tooling${endpoint}`;
    const sfArgs = ['api', 'request', 'rest', url, '--method', method];
    if (targetOrg) sfArgs.push('--target-org', targetOrg);

    const tmpFile = body
        ? join(tmpdir(), `sf_compile_${process.pid}_${Date.now()}.json`)
        : null;

    if (body) {
        writeFileSync(tmpFile, JSON.stringify(body));
        sfArgs.push('--body', `@${tmpFile}`);
    }

    let output;
    try {
        output = sf(sfArgs);
    } finally {
        if (tmpFile) try { unlinkSync(tmpFile); } catch {}
    }

    if (!output || !output.trim()) return {};

    const parsed = JSON.parse(output);
    if (Array.isArray(parsed) && parsed[0]?.errorCode) {
        throw new Error(`${parsed[0].errorCode}: ${parsed[0].message}`);
    }
    return parsed;
}

// ── Async CLI helpers (for parallel operations) ──

let tmpCounter = 0;

async function sfAsync(sfArgs) {
    try {
        const { stdout } = await execFileAsync('sf', sfArgs, {
            encoding: 'utf-8',
            maxBuffer: 10 * 1024 * 1024
        });
        return stdout;
    } catch (error) {
        if (error.stdout?.trim()) return error.stdout;
        const msg = error.stderr?.replace(/^Warning:.*\n?/gm, '').trim() || error.message;
        throw new Error(msg);
    }
}

async function restAsync(endpoint, method = 'GET', body = null) {
    const url = `/services/data/v${API_VERSION}/tooling${endpoint}`;
    const sfArgs = ['api', 'request', 'rest', url, '--method', method];
    if (targetOrg) sfArgs.push('--target-org', targetOrg);

    // Each concurrent call gets its own temp file to avoid write conflicts
    const tmpFile = body
        ? join(tmpdir(), `sf_compile_${process.pid}_${++tmpCounter}.json`)
        : null;

    if (body) {
        writeFileSync(tmpFile, JSON.stringify(body));
        sfArgs.push('--body', `@${tmpFile}`);
    }

    let output;
    try {
        output = await sfAsync(sfArgs);
    } finally {
        if (tmpFile) try { unlinkSync(tmpFile); } catch {}
    }

    if (!output || !output.trim()) return {};

    const parsed = JSON.parse(output);
    if (Array.isArray(parsed) && parsed[0]?.errorCode) {
        throw new Error(`${parsed[0].errorCode}: ${parsed[0].message}`);
    }
    return parsed;
}

async function batchAsync(items, fn, concurrency = CONCURRENCY) {
    const results = [];
    for (let i = 0; i < items.length; i += concurrency) {
        const batch = items.slice(i, i + concurrency);
        const batchResults = await Promise.all(batch.map(fn));
        results.push(...batchResults);
    }
    return results;
}

// ── Error formatting ──

function formatCompilerErrors(errorsField) {
    if (!errorsField) return null;

    try {
        const errors =
            typeof errorsField === 'string'
                ? JSON.parse(errorsField)
                : errorsField;
        if (!Array.isArray(errors) || errors.length === 0) return null;

        const lines = [];
        for (const err of errors) {
            const name = err.name || err.extent || 'Unknown';
            const location = err.line
                ? `: line ${err.line}, column ${err.column}`
                : '';
            const message = err.problem || err.message || 'Unknown error';
            lines.push(`${name}${location}: ${message}`);
        }
        return lines.join('\n');
    } catch {
        return String(errorsField);
    }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
    console.log('Compile All Apex Classes & Triggers\n');

    // 1 ── Query classes and triggers (including Body for recompilation)
    const filter = namespaceFilter();
    if (namespace) console.log(`Using namespace: ${namespace}\n`);

    const classes = query(
        `SELECT Id, Name, Body FROM ApexClass ${filter} ORDER BY Name`
    );
    const triggers = query(
        `SELECT Id, Name, Body FROM ApexTrigger ${filter} ORDER BY Name`
    );
    console.log(
        `Found ${classes.length} classes and ${triggers.length} triggers\n`
    );

    const total = classes.length + triggers.length;
    if (total === 0) {
        console.log('Nothing to compile.');
        return;
    }

    // 2 ── Create MetadataContainer
    const container = rest('/sobjects/MetadataContainer', 'POST', {
        Name: `Compile_${Date.now()}`
    });
    const containerId = container.id;

    // 3 ── Add classes and triggers to the container (parallel batches)
    const members = [
        ...classes.map((cls) => ({ type: 'ApexClassMember', entity: cls })),
        ...triggers.map((trg) => ({ type: 'ApexTriggerMember', entity: trg }))
    ];

    let completed = 0;
    await batchAsync(members, async ({ type, entity }) => {
        await restAsync(`/sobjects/${type}`, 'POST', {
            MetadataContainerId: containerId,
            ContentEntityId: entity.Id,
            Body: entity.Body
        });
        completed++;
        process.stdout.write(`\r  [${completed}/${total}] Adding members...`);
    });
    console.log(`\r  [${total}/${total}] Added all members ✓   `);

    // 4 ── Submit compile request
    console.log('\nCompiling...');
    const asyncReq = rest('/sobjects/ContainerAsyncRequest', 'POST', {
        MetadataContainerId: containerId,
        IsCheckOnly: true
    });

    // 5 ── Poll until complete
    let dots = 0;
    while (true) {
        const status = rest(
            `/sobjects/ContainerAsyncRequest/${asyncReq.id}`
        );
        const state = status.State;

        if (state === 'Completed') {
            console.log(
                `\n✅ Compiled ${classes.length} classes and ${triggers.length} triggers.`
            );
            break;
        }

        if (
            ['Failed', 'Error', 'Aborted', 'Invalidated'].includes(state)
        ) {
            console.error(`\n❌ Compilation ${state}`);

            // Try CompilerErrors from the REST response first
            let formatted = formatCompilerErrors(status.CompilerErrors);

            // Fallback: query via SOQL (REST GET sometimes omits CompilerErrors)
            if (!formatted) {
                try {
                    const records = query(
                        `SELECT CompilerErrors FROM ContainerAsyncRequest WHERE Id = '${asyncReq.id}'`
                    );
                    if (records.length > 0) {
                        formatted = formatCompilerErrors(
                            records[0].CompilerErrors
                        );
                    }
                } catch {}
            }

            if (formatted) {
                console.error('\nCompilation Errors found:');
                console.error(formatted);
            }

            if (status.ErrorMsg) {
                console.error(`\nError: ${status.ErrorMsg}`);
            }

            if (!formatted && !status.ErrorMsg) {
                console.error(
                    '\nNo error details available. Check Setup → Apex Classes in the org.'
                );
            }

            process.exit(1);
        }

        dots = (dots + 1) % 4;
        process.stdout.write(
            `\r  ${state}${'.'.repeat(dots)}${' '.repeat(3 - dots)}   `
        );
        await sleep(POLL_MS);
    }

    // 6 ── Clean up container
    try {
        rest(`/sobjects/MetadataContainer/${containerId}`, 'DELETE');
    } catch {}
}

main().catch((err) => {
    console.error('\nError:', err.message);
    process.exit(1);
});
