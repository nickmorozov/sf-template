Help me retrieve metadata from my Salesforce org.

First, check the current state:

1. Run `sf org list` to show connected orgs and the default

Then ask me:

- Do I want to retrieve everything, a specific metadata type, or specific components?

**Retrieve everything:**

```bash
npm run source:pull
```

**Retrieve a specific metadata type:**

```bash
sf project retrieve start --metadata ApexClass --wait 10
sf project retrieve start --metadata LightningComponentBundle --wait 10
sf project retrieve start --metadata CustomObject --wait 10
sf project retrieve start --metadata Flow --wait 10
sf project retrieve start --metadata PermissionSet --wait 10
```

**Retrieve specific component(s):**

```bash
sf project retrieve start --source-dir force-app/main/default/classes/MyClass.cls --wait 10
sf project retrieve start --metadata CustomObject:MyObject__c --wait 10
```

After retrieval:

1. Show what was retrieved
2. Run `git diff --stat` to show what changed locally
3. Summarize the changes in plain language
4. If Apex was retrieved, suggest running tests: `sf apex run test --synchronous --result-format human`
5. Suggest next steps: review changes, commit to a feature branch (direct commits to main/dev/qa/uat are blocked)
