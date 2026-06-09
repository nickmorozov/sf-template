Help me debug an issue in my Salesforce org.

Ask me:

1. What's happening? (error message, unexpected behavior, deployment failure)
2. When does it happen? (on deploy, at runtime, in a specific component/page)
3. Can you paste the error message or screenshot?

**For deployment errors:**

- Read the error message and explain it in plain language
- Check the relevant source files for the issue
- Provide the fix

**For runtime Apex errors:**

1. Check debug logs: `sf apex log list` then `sf apex log get --log-id <id>`
2. Identify the exception type and line number
3. Read the relevant Apex class
4. Explain the root cause and provide the fix

Common Apex errors and causes:

- `System.NullPointerException`: Accessing a property on a null object — add null checks
- `System.QueryException: List has no rows`: SOQL returned nothing — use List instead of single record assignment
- `System.LimitException: Too many SOQL queries`: SOQL inside a loop — move query outside loop, use collections
- `System.DmlException: MIXED_DML_OPERATIONS`: DML on setup + non-setup objects — separate into async
- `System.StringException: Invalid id`: Bad ID format — validate input before using

**For LWC errors:**

1. Ask me to check browser console (F12 > Console) for the error
2. Common issues: wire not returning data, event not dispatching, navigation not working
3. Check the JS file, HTML template, and meta XML for issues

**For test failures:**

1. Run the failing test: `sf apex run test --class-names <TestClass> --synchronous --result-format human`
2. Read the test class and the class being tested
3. Identify why the assertion failed or exception occurred
4. Fix the issue (could be in the test or the actual code)

Always explain the problem and fix in plain, non-technical language where possible.
