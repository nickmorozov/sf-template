// @ts-check

import globals from 'globals';
import path from 'node:path';
// noinspection JSUnresolvedReference
import { fileURLToPath } from 'node:url';
import js from '@eslint/js';
import eslint from '@eslint/js';
import { FlatCompat } from '@eslint/eslintrc';
import tseslint from 'typescript-eslint';
import importPlugin from 'eslint-plugin-import';

// This allows us to use older rule sets
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const compat = new FlatCompat({
    baseDirectory: __dirname,
    recommendedConfig: js.configs.recommended,
    allConfig: js.configs.all
});

// noinspection JSCheckFunctionSignatures
export default tseslint.config(
    // Always use the recommended rule set
    eslint.configs.recommended,

    // LWC TypeScript non-test files,
    ...compat.extends('@salesforce/eslint-config-lwc/recommended'),
    {
        extends: [...tseslint.configs.recommended],
        plugins: {
            import: importPlugin
        },
        files: ['**/*.ts'],
        languageOptions: {
            globals: {
                ...globals.node
            }
        },
        rules: {
            '@typescript-eslint/no-explicit-any': 'off'
        },
        settings: {
            'import/resolver': {
                typescript: true
            }
        }
    },

    // LWC TypeScript Jest tests
    {
        extends: [...tseslint.configs.recommended],
        plugins: {
            import: importPlugin
        },
        files: ['**/*.test.ts'],
        languageOptions: {
            globals: {
                ...globals.node
            }
        },
        rules: {
            '@lwc/lwc/no-unexpected-wire-adapter-usages': 'off',
            '@typescript-eslint/no-explicit-any': 'off'
        },
        settings: {
            'import/resolver': {
                typescript: true
            }
        }
    },

    // LWC JavaScript Jest tests
    {
        files: ['**/*.test.js'],
        languageOptions: {
            globals: {
                ...globals.node
            }
        },
        rules: {
            '@lwc/lwc/no-unexpected-wire-adapter-usages': 'off'
        }
    }
);