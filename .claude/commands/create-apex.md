Create a new Apex class (and its test class).

Ask me these questions before generating anything:

1. What type? (Service class, Trigger Handler, Controller, Batch, Schedulable, Queueable, Invocable for Flows, or REST API)
2. What should it do? (describe the functionality)
3. What objects does it work with?
4. Does it need to be called from LWC? (if so, methods need @AuraEnabled)

Then generate:

**The main class** — Following these rules:

- Use `with sharing` by default
- Bulkify all methods (accept and return Lists/Maps, never single records)
- No SOQL or DML inside loops
- Use bind variables in SOQL (never string concatenation)
- Check CRUD/FLS with `WITH SECURITY_ENFORCED` in SOQL
- If it's a trigger handler: use the one-trigger-per-object pattern with handler class
- If it's for LWC: use `@AuraEnabled(cacheable=true)` for read operations, `@AuraEnabled` for write operations
- If it's a Batch class: implement `Database.Batchable<sObject>` with start, execute, finish methods
- If it's Invocable: use `@InvocableMethod` and `@InvocableVariable` with proper labels and descriptions
- See `.claude/rules/apex-patterns.md` for full pattern reference

**The test class** — Following these rules:

- Name it `<ClassName>Test`
- Use `@isTest` annotation
- Use `@TestSetup` for test data creation
- Test positive, negative, and bulk (200+ records) scenarios
- Use `System.assertEquals` / `System.assert` with assertion messages
- Test as different user profiles when permissions matter using `System.runAs()`
- Target 90%+ code coverage
- Use `Test.startTest()` and `Test.stopTest()` around the method being tested
- See `.claude/rules/testing.md` for full testing reference

Place class files in: `force-app/main/default/classes/`

After generating, remind me to:

1. Deploy: `npm run source:push`
2. Run tests: `sf apex run test --class-names ClassNameTest --synchronous --result-format human --code-coverage`
3. Note: `sf scanner run` will check the code automatically on commit via lint-staged
