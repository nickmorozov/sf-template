# Security Rules

## CRUD/FLS Enforcement

- Always use `WITH SECURITY_ENFORCED` in SOQL queries:
    ```apex
    List<Account> accts = [SELECT Id, Name FROM Account WITH SECURITY_ENFORCED];
    ```
- For DML operations, use `Security.stripInaccessible()`:
    ```apex
    SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, records);
    insert decision.getRecords();
    ```
- Alternative: check `Schema.sObjectType.Account.fields.Name.isAccessible()` before field access.
- `sf scanner run` enforces these rules on every commit via lint-staged.

## SOQL Injection Prevention

- **Always use bind variables** (`:variableName`) in SOQL:

    ```apex
    // GOOD
    String acctName = 'Acme';
    List<Account> accts = [SELECT Id FROM Account WHERE Name = :acctName];

    // BAD — vulnerable to injection
    String query = 'SELECT Id FROM Account WHERE Name = \'' + acctName + '\'';
    ```

- If dynamic SOQL is absolutely necessary, use `String.escapeSingleQuotes()`.
- Never build SOQL from user input without sanitization.

## Sharing Model

- Default to `with sharing` on all classes.
- Only use `without sharing` when:
    - The class runs system-level operations (e.g., platform event handlers, certain batch jobs).
    - You document the reason in a code comment.
- Use `inherited sharing` when the class should respect the caller's sharing context.
- Trigger handlers typically use `without sharing` since triggers run in system context — document this.

## Profile Security

- The pre-commit hook automatically strips non-essential `<userPermissions>` from staged profile XML files.
- Only these permissions are preserved: AuthorApex, InstallPackaging, InboundMigrationToolsUser, ManageAuthProviders, ModifyAllData, ModifyMetadata.
- Use Permission Sets instead of Profiles for granting permissions.

## Sensitive Data

- Never log sensitive data (SSN, credit card numbers, PII) in debug statements.
- Never hardcode IDs, credentials, API keys, or passwords.
- Store secrets in **Named Credentials** or **Custom Metadata Types** (protected).
- Use `Crypto` class for encryption needs.
- Remove all `System.debug()` statements containing sensitive data before deploying to production.

## XSS Prevention (Visualforce / Aura)

- Use `HTMLENCODE()`, `JSENCODE()`, `URLENCODE()` in Visualforce merge fields.
- In LWC, the framework auto-escapes by default — don't use `lwc:dom="manual"` with unsanitized input.

## Governor Limits as Security

- Unbounded SOQL (no `WHERE` or `LIMIT`) can be exploited to harvest data. Always filter queries.
- Rate-limit callouts and external API interactions to prevent abuse.
