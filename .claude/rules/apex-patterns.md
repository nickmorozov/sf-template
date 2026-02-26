# Apex Patterns & Conventions

## Naming Conventions

- Classes: PascalCase (`AccountService`, `OpportunityTriggerHandler`)
- Methods: camelCase (`getAccountById`, `processRecords`)
- Variables: camelCase (`accountList`, `contactMap`)
- Constants: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)
- Test methods: descriptive names (`testBulkInsertCreatesContacts`, `testNegativeCaseThrowsError`)
- Test classes: `<ClassName>Test` (e.g., `AccountServiceTest`)

## Trigger Handler Pattern

- One trigger per object, all events in one trigger.
- Thin trigger that delegates to a handler class:

```apex
trigger AccountTrigger on Account(before insert, before update, after insert, after update) {
    AccountTriggerHandler handler = new AccountTriggerHandler();
    handler.run();
}
```

- Handler class encapsulates all logic with methods per event (beforeInsert, afterUpdate, etc.).
- Handler must bulkify — always process `Trigger.new` as a collection.

## Service Layer Pattern

- Service classes contain reusable business logic.
- Accept and return `List`/`Map` types, never single records.
- Use `with sharing` by default.
- Methods called from LWC need `@AuraEnabled(cacheable=true)` for reads, `@AuraEnabled` for writes.

## Batch Apex

```apex
public class MyBatch implements Database.Batchable<sObject>, Database.Stateful {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM Account]);
    }
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        // Process records
    }
    public void finish(Database.BatchableContext bc) {
        // Post-processing, send notifications
    }
}
```

- Use `Database.Stateful` only when you need to maintain state across batches.
- Default scope is 200; lower it for callout-heavy or complex processing.
- Call with: `Database.executeBatch(new MyBatch(), scopeSize);`

## Queueable Apex

```apex
public class MyQueueable implements Queueable {
    public void execute(QueueableContext context) {
        // Async processing
    }
}
```

- Preferred over `@future` — supports complex types and job chaining.
- Can chain: call `System.enqueueJob()` from within `execute()` (max depth: 5 in most contexts).

## Schedulable Apex

```apex
public class MySchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new MyBatch());
    }
}
```

- Schedule with: `System.schedule('Job Name', cronExpression, new MySchedulable());`
- Common cron: `'0 0 1 * * ?'` = daily at 1 AM.

## Invocable Actions (for Flows)

```apex
public class MyInvocable {
    @InvocableMethod(label='Do Something' description='Description for Flow builders')
    public static List<Response> doSomething(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response res = new Response();
            // Process
            responses.add(res);
        }
        return responses;
    }

    public class Request {
        @InvocableVariable(label='Record Id' required=true)
        public Id recordId;
    }

    public class Response {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
```

- Always use inner `Request`/`Response` classes with `@InvocableVariable`.
- Labels and descriptions are what Flow builders see — make them clear.
- Method must accept and return `List<>` even for single-record invocations.

## Pre-commit Pipeline Integration

- `sf scanner run` checks Apex on every commit via lint-staged (catches common violations automatically).
- The pre-commit hook strips non-essential `<userPermissions>` from staged profile XMLs (preserves only: AuthorApex, InstallPackaging, InboundMigrationToolsUser, ManageAuthProviders, ModifyAllData, ModifyMetadata).
- Direct commits to `main`, `dev`, `qa`, `uat` are blocked by the branch guard. Use feature branches.

## General Rules

- Prefer `with sharing` unless there's a documented reason for `without sharing`.
- Use `Database.insert(records, false)` for partial success when appropriate.
- Use custom exceptions (`throw new MyCustomException('msg')`) instead of generic exceptions.
- Use bind variables in SOQL — never string concatenation.
