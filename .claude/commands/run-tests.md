Run Apex tests and help me understand the results.

Ask me: Do I want to run all local tests, a specific test class, or a specific test method?

**All local tests with coverage:**

```bash
sf apex run test --synchronous --result-format human --test-level RunLocalTests --code-coverage
```

**Specific class with coverage:**

```bash
sf apex run test --class-names <TestClassName> --synchronous --result-format human --code-coverage
```

**Specific method:**

```bash
sf apex run test --tests <TestClassName.methodName> --synchronous --result-format human
```

**LWC Jest tests:**

```bash
npm run test:unit                                          # All LWC tests
npm run test:unit:coverage                                 # With coverage report
npx sfdx-lwc-jest -- --testPathPattern="componentName"     # Single component
```

After tests run:

1. Show me pass/fail results clearly
2. If `--code-coverage` was used, show per-class coverage percentages
3. Flag any classes below 75% coverage — these will block production deployment (target 90%+)
4. If any tests failed, explain the failures in plain language
5. If coverage is low, identify which lines are not covered and suggest test scenarios

Note: lint-staged runs `sfdx-lwc-jest -- --bail --findRelatedTests` on changed test files and `sf scanner run` on Apex files automatically on every commit.
