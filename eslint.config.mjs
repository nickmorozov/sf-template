'use strict';

import {defineConfig} from "eslint/config";
import eslintJs from "@eslint/js";
import jestPlugin from "eslint-plugin-jest";
import auraConfig from "@salesforce/eslint-plugin-aura";
import salesforceLwcConfig from "@salesforce/eslint-config-lwc";
import globals from "globals";
import tseslint from "typescript-eslint";
import importPlugin from "eslint-plugin-import";
import htmlPlugin from "@html-eslint/eslint-plugin";
import salesforceUxSlds from "@salesforce-ux/eslint-plugin-slds";
import htmlParser from "@html-eslint/parser";

export default defineConfig([
    // Global config
    {
        ignores: [
            // Config files
            'eslint.config.*',
            'jest.config.js',
            // Static resource bundle contents
            '**/staticresources/**'
        ]
    },

    // Aura configuration
    {
        files: ['**/aura/**/*.js'],
        extends: [
            ...auraConfig.configs.recommended,
            ...auraConfig.configs.locker
        ],
        languageOptions: {
            ecmaVersion: 5
        },
        rules: {
            'no-unused-expressions': 'off'
        }
    },

    // LWC JavaScript configuration
    {
        files: ['**/lwc/**/*.js'],
        plugins: {
            importPlugin
        },
        extends: [...salesforceLwcConfig.configs.recommended],
        languageOptions: {
            ecmaVersion: 'latest',
            globals: {
                ...globals.node
            }
        }
    },

    // LWC TypeScript configuration
    tseslint.config({
        files: ['**/lwc/**/*.ts'],
        plugins: {
            importPlugin
        },
        extends: [
            ...salesforceLwcConfig.configs.recommended,
            ...tseslint.configs.recommended
        ],
        languageOptions: {
            ecmaVersion: 'latest',
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
    }),

    // LWC JavaScript Jest test configuration
    {
        files: ['**/lwc/**/*.test.js'],
        extends: [...salesforceLwcConfig.configs.recommended],
        rules: {
            '@lwc/lwc/no-unexpected-wire-adapter-usages': 'off'
        },
        languageOptions: {
            ecmaVersion: 'latest',
            globals: {
                ...globals.node
            }
        }
    },

    // LWC TypeScript Jest test configuration
    tseslint.config({
        files: ['**/lwc/**/*.test.ts'],
        plugins: {
            importPlugin
        },
        extends: [
            ...salesforceLwcConfig.configs.recommended,
            ...tseslint.configs.recommended
        ],
        rules: {
            '@lwc/lwc/no-unexpected-wire-adapter-usages': 'off',
            '@typescript-eslint/no-explicit-any': 'off'
        },
        languageOptions: {
            ecmaVersion: 'latest',
            globals: {
                ...globals.node
            }
        },
        settings: {
            'import/resolver': {
                typescript: true
            }
        }
    }),

    // Jest mocks configuration
    {
        files: ['**/jest-mocks/**/*.js'],
        languageOptions: {
            sourceType: 'module',
            ecmaVersion: 'latest',
            globals: {
                ...globals.node,
                ...globals.es2021,
                ...jestPlugin.environments.globals.globals,
                CustomEvent: 'readonly',
                window: 'readonly'
            }
        },
        plugins: {
            eslintJs
        },
        extends: ['eslintJs/recommended']
    },

    // SLDS Linter configuration for Aura component and LWC HTML files
    {
        files: ['**/aura/**/*.cmp', '**/lwc/**/*.html'],
        plugins: {
            htmlPlugin,
            '@salesforce-ux/slds': salesforceUxSlds
        },
        languageOptions: {
            parser: htmlParser
        },
        rules: {
            '@salesforce-ux/slds/enforce-bem-usage': 'error',
            '@salesforce-ux/slds/no-deprecated-classes-slds2': 'error',
            '@salesforce-ux/slds/modal-close-button-issue': 'error'
        }
    }
]);
