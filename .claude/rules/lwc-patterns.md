# LWC Patterns & Conventions

## Component Structure

Every LWC component has:

- `componentName.html` — template markup
- `componentName.js` — controller logic
- `componentName.js-meta.xml` — metadata config (API version, targets, visibility)
- `componentName.css` — optional styles (use SLDS classes first, checked by Stylelint)
- `__tests__/componentName.test.js` — Jest test file

## Naming

- Component folders and files: camelCase (`myComponent`)
- In HTML markup: kebab-case with namespace (`c-my-component`)
- JS class: PascalCase (`export default class MyComponent`)
- Custom events: lowercase no hyphens (`customevent`, not `custom-event`)

## Reactivity

- `@api` — public properties exposed to parent components or App Builder.
- `@track` — only needed for object/array deep mutations. Primitive reactive properties don't need it.
- Reassign arrays/objects to trigger reactivity: `this.items = [...this.items, newItem]`
- Never mutate `@wire` results directly — clone data before modifying.

## Wire Adapters

```javascript
import { LightningElement, wire } from 'lwc';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

export default class MyComponent extends LightningElement {
    @wire(getAccounts, { searchKey: '$searchTerm' })
    wiredAccounts;
}
```

- Use `@wire` for declarative data access (Apex methods or LDS).
- Reactive variables use `$` prefix in wire parameters.
- `@wire` results have `{ data, error }` shape.
- Prefer **Lightning Data Service (LDS)** over Apex for simple CRUD:
    - `getRecord`, `getFieldValue`, `createRecord`, `updateRecord`, `deleteRecord`

## Imperative Apex Calls

```javascript
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

async handleSearch() {
    try {
        this.accounts = await getAccounts({ searchKey: this.searchTerm });
    } catch (error) {
        this.showToast('Error', error.body.message, 'error');
    }
}
```

- Use imperative calls for user-triggered actions (button clicks, form submits).
- Always wrap in try/catch.

## Events

- Child-to-parent: `this.dispatchEvent(new CustomEvent('select', { detail: recordId }))`.
- Parent listens with `onselect` handler in template.
- Cross-DOM (unrelated components): use Lightning Message Service (LMS).

## Navigation

```javascript
import { NavigationMixin } from 'lightning/navigation';

export default class MyComponent extends NavigationMixin(LightningElement) {
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Account', actionName: 'view' },
        });
    }
}
```

## Toast Notifications

```javascript
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}
```

## Template Best Practices

- Use `lwc:if`, `lwc:elseif`, `lwc:else` (NOT deprecated `if:true`/`if:false`).
- Use `lightning-*` base components (lightning-card, lightning-datatable, lightning-input, etc.).
- Show loading spinners while data loads (`lightning-spinner`).
- Display error states with user-friendly messages.
- Use SLDS utility classes before writing custom CSS.

## Meta XML Targets

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__RecordPage</target>
        <target>lightning__AppPage</target>
        <target>lightning__HomePage</target>
    </targets>
</LightningComponentBundle>
```

## ESLint Configuration

The project uses ESLint v9 flat config with 8 blocks scoped by file pattern:

- **Aura JS** (`**/aura/**/*.js`) — ES5 only. No arrow functions, const/let, template literals.
- **LWC JS** (`**/lwc/**/*.js`) — Latest ES, LWC recommended rules.
- **LWC TypeScript** (`**/lwc/**/*.ts`) — TypeScript-eslint, `no-explicit-any` off.
- **LWC Tests** (`**/lwc/**/*.test.js`, `**/lwc/**/*.test.ts`) — `no-unexpected-wire-adapter-usages` off.
- **Jest Mocks** (`**/jest-mocks/**/*.js`) — Jest globals (CustomEvent, window).
- **SLDS HTML** (`**/aura/**/*.cmp`, `**/lwc/**/*.html`) — BEM enforcement, no deprecated SLDS2 classes.

When adding new lint rules, identify the correct block by file pattern.

## Stylelint for CSS

- Uses `@salesforce-ux/stylelint-plugin-slds` with 15 SLDS-specific CSS rules.
- Key rules: `no-slds-class-overrides`, `no-hardcoded-values-slds2`, `no-slds-private-var`, `no-unsupported-hooks-slds2`.
- Use SLDS design tokens and hooks instead of hardcoded values.

## Jest Testing

```javascript
import { createElement } from 'lwc';
import MyComponent from 'c/myComponent';
import getAccounts from '@salesforce/apex/AccountController.getAccounts';

jest.mock(
    '@salesforce/apex/AccountController.getAccounts',
    () => ({
        default: jest.fn(),
    }),
    { virtual: true }
);

describe('c-my-component', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('displays accounts when data is returned', async () => {
        getAccounts.mockResolvedValue([{ Id: '001xx', Name: 'Test' }]);
        const element = createElement('c-my-component', { is: MyComponent });
        document.body.appendChild(element);

        await Promise.resolve();
        const items = element.shadowRoot.querySelectorAll('.account-item');
        expect(items.length).toBe(1);
    });
});
```

- Test match pattern: `**/lwc/*/__tests__/*.test.js`
- Run all: `npm run test:unit`
- Run with coverage: `npm run test:unit:coverage`
- Run single component: `npx sfdx-lwc-jest -- --testPathPattern="componentName"`
- Config: `passWithNoTests: true`, coverage reporters: text + lcov
- Mock all `@salesforce/` imports (apex, schema, label, etc.).
- Use `Promise.resolve()` or `await flushPromises()` to wait for DOM updates.
- Clean up DOM in `afterEach` to avoid test pollution.
