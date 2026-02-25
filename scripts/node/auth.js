#!/usr/bin/env node

const { exec } = require('child_process');
const { program } = require('commander');

program
    .description('Authenticate to Salesforce org')
    .argument('<domain>', 'Salesforce domain')
    .argument('<alias>', 'Alias for the org')
    .action(async (domain, alias, isDefault) => {
        try {
            // Check if Salesforce CLI is installed
            await checkSalesforceCli();

            // Build URL
            let url = 'https://';
            if (domain.includes('--')) {
                url += `${domain}.sandbox`;
            } else {
                url += domain;
            }
            url += '.my.salesforce.com';

            // Authenticate
            const command = `sf org login web --instance-url "${url}" --alias "${alias}" --set-default`;

            console.log(`Authenticating to ${url} as ${alias}...`);

            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.error(`Error: ${error.message}`);
                    process.exit(1);
                }
                if (stderr) {
                    console.error(`Warning: ${stderr}`);
                }
                console.log(stdout);
                console.log(`Authorized ${url} as ${alias}`);
            });
        } catch (error) {
            console.error(error.message);
            process.exit(1);
        }
    });

function checkSalesforceCli() {
    return new Promise((resolve, reject) => {
        exec('sf --version', (error) => {
            if (error) {
                reject(new Error('Salesforce CLI is not installed. Please install it first.'));
            } else {
                resolve();
            }
        });
    });
}

program.parse();

// Usage examples:
// node scripts/auth.js cgtpm-dev-ed my-first-tpm-dev
// node scripts/auth.js client-domain--dev client-dev
// node scripts/auth.js client-domain client-prod
