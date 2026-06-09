Help me deploy to my Salesforce org.

First, check the current state:

1. Run `sf org list` to show connected orgs and the default
2. Run `sf project deploy preview` to show what would be deployed

Then ask me:

- Do I want to deploy everything, or specific components?
- Is this going to a sandbox or production?
- Do I want a validation-only dry run first? (recommended for production)

For **validation only (dry run)**:

```bash
npm run source:validate
```

For **sandbox** deployment:

```bash
npm run source:push
```

For **production** deployment (requires tests):

```bash
sf project deploy start --source-dir force-app --test-level RunLocalTests --wait 10
```

For **specific files**:

```bash
sf project deploy start --source-dir <path-to-specific-files> --wait 10
```

After deployment:

- Show me the deployment status and any errors
- If there are errors, explain what went wrong in plain language and help me fix them
- If successful, confirm what was deployed

Common deployment error fixes:

- **Code coverage < 75%**: Run `sf apex run test --synchronous --result-format human --code-coverage` to see per-class coverage
- **Missing dependencies**: Deploy dependent metadata first
- **FIELD_INTEGRITY_EXCEPTION**: Usually a missing field or relationship
- **DUPLICATE_VALUE**: Record or metadata already exists with that name
- **Test failures**: Run tests separately to isolate: `sf apex run test --class-names FailingTest --synchronous --result-format human`
