Help me build a SOQL query.

Ask me:

1. What object(s) do I want to query?
2. What fields do I need?
3. What are my filter criteria?
4. Do I need related records? (parent-to-child or child-to-parent)
5. Any sorting or limits?

Then:

1. Build the SOQL query with proper syntax
2. Explain what the query does in plain language
3. Run it against my org so I can see the results:
    ```bash
    sf data query --query "<the query>"
    ```
4. If the query fails, explain why and fix it

**SOQL tips to follow:**

- Use bind variables (`:variableName`) in Apex code, not string concatenation
- Always include `WITH SECURITY_ENFORCED` when used in Apex
- Include `LIMIT` to avoid returning too many records
- Use indexed fields in WHERE clauses for performance (Id, Name, CreatedDate, SystemModstamp, RecordType, lookup fields)
- Use relationship queries instead of multiple separate queries
- Parent-to-child: `SELECT Id, (SELECT Id FROM Contacts) FROM Account`
- Child-to-parent: `SELECT Id, Account.Name FROM Contact`

If I want to use this in Apex code, wrap it properly and show me how to handle the results (List, Map, or single record with proper null checks).
