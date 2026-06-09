const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        ...jestConfig.moduleNameMapper,
        '^lightning/modal$': '<rootDir>/jest-mocks/lightning/modal',
    },
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver'],
    testPathIgnorePatterns: ['<rootDir>/node_modules/', '<rootDir>/.worktrees/', '<rootDir>/.claude/'],
    testEnvironment: 'node',
    testMatch: ['**/lwc/*/__tests__/*.test.js'],
    collectCoverage: true,
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov'],
    passWithNoTests: true,
};
