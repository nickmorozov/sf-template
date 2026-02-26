Create a new Lightning Web Component.

Ask me these questions before generating anything:

1. What should the component be called? (camelCase, e.g., accountList)
2. What should it do? (describe the functionality)
3. Where will it be used? (Record Page, App Page, Home Page, Flow Screen, or embedded in another component)
4. Does it need to call Apex, or can it use Lightning Data Service?
5. What object is it related to (if any)?

Then generate all required files:

**componentName.js** — Include:

- Proper imports (@api, @wire, @track only if needed)
- Import Apex methods if needed
- Proper error handling with try/catch
- JSDoc comments on public properties

**componentName.html** — Include:

- SLDS classes for styling (checked by Stylelint — see `.claude/rules/lwc-patterns.md`)
- Proper use of lightning-\* base components
- Conditional rendering with `lwc:if`/`lwc:elseif`/`lwc:else` (NOT `if:true`/`if:false` which is deprecated)
- Loading spinner while data loads
- Error state display

**componentName.js-meta.xml** — Include:

- apiVersion set to 62.0
- isExposed set to true
- Correct targets based on where it will be used

**componentName.css** — Only if custom styles are needed beyond SLDS. Use SLDS design tokens and hooks instead of hardcoded values (enforced by Stylelint).

****tests**/componentName.test.js** — Include:

- Import createElement from 'lwc'
- Import the component
- Mock any @salesforce/ imports (apex, schema, labels)
- afterEach cleanup (remove DOM elements, clear mocks)
- Test: component renders successfully
- Test: displays data when wire/apex returns results
- Test: displays error state on failure
- Test: user interactions (button clicks, input changes) if applicable

Place all files in: `force-app/main/default/lwc/componentName/`

After generating, remind me to:

1. Deploy: `npm run source:push`
2. Run Jest tests: `npx sfdx-lwc-jest -- --testPathPattern="componentName"`
3. Preview with Local Dev: `sf lightning dev component --name componentName`
   Note: Hot reload works for HTML, CSS, and JS changes. New @api properties or @wire changes require deploy first.
