# Claude Code + Tooling Integration Design

## Context

Analyzed 6 Salesforce project templates (empty, standard, dancin, minlopro, claude, vibes) to identify the best configurations for sf-template. This design integrates Claude Code AI tooling, VS Code settings, and Salesforce MCP alongside the existing npm tooling stack.

## Decisions

| Question                   | Decision                                                                                   |
| -------------------------- | ------------------------------------------------------------------------------------------ |
| `.claude/` sync strategy   | Additive merge — template owns specific files, consumer adds freely                        |
| Hooks                      | All three: PreToolUse (block destructive), PostToolUse (Apex/LWC checks), Stop (reminders) |
| `.vscode/`                 | Synced verbatim (settings.json, extensions.json, launch.json)                              |
| `.mcp.json`                | Included — `@salesforce/mcp` with DEFAULT_TARGET_ORG                                       |
| Commands/Agents            | All 10 commands + 3 agents from example-template-claude, adapted for Corrao conventions    |
| `.claude/` merge mechanism | File-level tracking (like TEMPLATE_MANAGED_SCRIPTS)                                        |

## New Files

```
sf-template/
├── .claude/
│   ├── settings.json              # 3 hooks
│   ├── commands/                  # 10 slash commands
│   │   ├── create-lwc.md
│   │   ├── create-apex.md
│   │   ├── create-flow-apex.md
│   │   ├── deploy.md
│   │   ├── retrieve.md
│   │   ├── run-tests.md
│   │   ├── review.md
│   │   ├── soql.md
│   │   ├── debug.md
│   │   └── local-dev.md
│   ├── agents/                    # 3 agents
│   │   ├── sf-reviewer.md
│   │   ├── sf-deployer.md
│   │   └── sf-retriever.md
│   └── rules/                     # 4 reference docs
│       ├── apex-patterns.md
│       ├── lwc-patterns.md
│       ├── security.md
│       └── testing.md
├── .vscode/
│   ├── settings.json
│   ├── extensions.json
│   └── launch.json
└── .mcp.json
```

## sync.js Changes

### New constants

```js
const CLAUDE_MANAGED_FILES = [
    '.claude/commands/create-lwc.md',
    '.claude/commands/create-apex.md',
    '.claude/commands/create-flow-apex.md',
    '.claude/commands/deploy.md',
    '.claude/commands/retrieve.md',
    '.claude/commands/run-tests.md',
    '.claude/commands/review.md',
    '.claude/commands/soql.md',
    '.claude/commands/debug.md',
    '.claude/commands/local-dev.md',
    '.claude/agents/sf-reviewer.md',
    '.claude/agents/sf-deployer.md',
    '.claude/agents/sf-retriever.md',
    '.claude/rules/apex-patterns.md',
    '.claude/rules/lwc-patterns.md',
    '.claude/rules/security.md',
    '.claude/rules/testing.md',
];

const VSCODE_FILES = ['.vscode/settings.json', '.vscode/extensions.json', '.vscode/launch.json'];
```

### Changes to existing sync flow

1. Add `CLAUDE_MANAGED_FILES` and `VSCODE_FILES` to `syncCopyFiles()` loop
2. Add `.mcp.json` to `COPY_FILES`
3. New function `syncClaudeSettings()` — merges `.claude/settings.json` hooks
4. Add `@salesforce/mcp` to template `devDependencies`

### .claude/settings.json merge strategy

- Hooks are matched by `command` string
- Template hooks are added/updated
- Consumer hooks with commands not in template are preserved
- Top-level non-hook settings are preserved from consumer

## Content Adaptation (from example-template-claude)

### Commands

- Use `sf` CLI v2 (not legacy `sfdx`)
- Reference npm scripts (`source:push`, `source:validate`) instead of raw sf commands
- Enforce Corrao conventions: `with sharing` default, 4-space indent, trigger handler pattern
- `/create-lwc`: SLDS classes, Stylelint awareness
- `/run-tests`: reference `sf scanner run` from lint-staged, 75% min / 90% target coverage

### Agents

- `@sf-reviewer`: add Stylelint/SLDS checks, reference 8 ESLint config blocks
- `@sf-deployer`: use npm scripts
- `@sf-retriever`: use npm scripts

### Rules

- `apex-patterns.md`: pre-commit profile cleanup whitelist, sf scanner
- `lwc-patterns.md`: ESLint flat config blocks, SLDS HTML linting
- `security.md`: keep mostly as-is
- `testing.md`: reference jest.config.js, passWithNoTests

### Hooks

- PreToolUse: block `sf org delete`, `rm -rf force-app`, `git push --force`, `git reset --hard`
- PostToolUse: SOQL/DML in loops, `if:true`/`if:false` deprecation
- Stop: untested Apex reminder, undeployed files reminder

### .vscode/

- settings.json: search exclusions (node_modules, .sf, .sfdx, .template)
- extensions.json: SF DX, XML, ESLint, Prettier, Apex PMD, Stylelint
- launch.json: Apex Replay Debugger

### .mcp.json

- `@salesforce/mcp` with `--orgs DEFAULT_TARGET_ORG --toolsets all`

## What's NOT Changing

- Existing COPY_FILES, COPY_HOOKS, lint-staged, pre-commit hook
- syncPackageJson(), cleanLegacy(), fixGitignore(), syncDataManager()
- CLAUDE.md not synced to consumers (each project owns its own)
- No new npm scripts (commands are Claude slash commands)
- No CI/CD (stays project-specific)
