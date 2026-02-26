Review my Salesforce code for best practices, security issues, and governor limit violations.

If I don't specify files, ask me which files or components to review.

Check for these issues and flag them clearly:

**Governor Limit Violations (Critical):**

- SOQL queries inside loops
- DML statements inside loops
- Unbounded SOQL queries (missing LIMIT or WHERE clause)
- Excessive SOQL/DML that could hit 100/150 limits

**Security Issues (Critical):**

- SOQL injection (string concatenation instead of bind variables)
- Missing CRUD/FLS checks (no `WITH SECURITY_ENFORCED` or manual checks)
- `without sharing` used without justification
- Hardcoded IDs or credentials

**Bulkification (High):**

- Methods that only handle single records
- Triggers not bulkified for 200+ records
- Inefficient collection usage (lists where maps would be better)

**LWC Issues (High):**

- Using deprecated `if:true`/`if:false` instead of `lwc:if`
- Missing error handling on Apex calls
- Direct DOM manipulation instead of reactive properties
- Missing loading states
- Not cloning @wire results before modifying
- Hardcoded CSS values that should use SLDS tokens (checked by Stylelint)
- SLDS class overrides (flagged by Stylelint `no-slds-class-overrides` rule)

**Code Quality (Medium):**

- Missing test coverage for key scenarios
- Hardcoded strings that should be Custom Labels or Custom Metadata
- Missing null checks on collections or query results

For each issue found:

1. State the severity (Critical / High / Medium)
2. Explain the problem in plain language
3. Show the specific line(s)
4. Provide the fix

Reference `.claude/rules/` for detailed patterns: apex-patterns.md, lwc-patterns.md, security.md, testing.md
