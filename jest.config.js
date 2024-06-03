module.exports = {
    testEnvironment: 'node',
    testMatch: ['**/lwc/*/__tests__/*.test.js'],
    collectCoverage: true,
    coverageDirectory: 'coverage',
    coverageReporters: ['text', 'lcov'],
};
