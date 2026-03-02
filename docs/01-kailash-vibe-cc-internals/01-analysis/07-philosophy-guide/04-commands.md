# Command Philosophy and Quality Guide

## First Principles

### What Commands ARE
- **User Shortcuts**: Quick access to common workflows
- **Action Triggers**: Invoke agents or skills with predefined context
- **Workflow Initiators**: Start multi-step processes
- **Memorable Aliases**: Easy-to-remember names for complex operations

### What Commands are NOT
- **Standalone Logic**: Should invoke existing agents/skills
- **Implementation Details**: Should delegate, not implement
- **Documentation**: Should be minimal, action-focused

## The Command Contract

```
INPUT: User types /command-name [args]
       ↓
COMMAND RESPONSIBILITIES:
1. Parse arguments (if any)
2. Set up context
3. Invoke appropriate agent/skill
4. Return control to conversation
       ↓
OUTPUT: Agent/skill execution or helpful error
```

## Structure Standards

### Command File Structure
```markdown
---
name: command-name
description: What this command does (max 80 chars)
arguments: [optional] Description of arguments
---

# /command-name

[Brief instruction to invoke appropriate agent/skill]

## Arguments
[If applicable, describe argument usage]

## Examples
/command-name
/command-name arg1 arg2
```

### Naming Conventions
```
GOOD names (memorable, verb-first):
├── /commit - Create a commit
├── /review - Review code
├── /test - Run tests
├── /plan - Create a plan
└── /fix - Fix an issue

POOR names (hard to remember):
├── /create-new-commit-with-message
├── /execute-code-review-process
├── /run-all-tests-and-report
└── /generate-implementation-plan
```

## Quality Criteria

### Length Guidelines
| Quality | Lines | Purpose |
|---------|-------|---------|
| Minimal (<10) | Single action | /commit, /test |
| Short (10-30) | With context | /review, /plan |
| Medium (30-50) | Complex workflow | /deploy, /release |
| Too Long (>50) | Should be agent/skill | Refactor needed |

### Command Categories

#### 1. Action Commands
Direct actions with immediate results.
```markdown
/commit - Create commit with message
/push - Push to remote
/test - Run test suite
/build - Build project
```

#### 2. Workflow Commands
Start multi-step processes.
```markdown
/plan - Start planning mode
/review - Code review workflow
/refactor - Refactoring workflow
/deploy - Deployment workflow
```

#### 3. Information Commands
Retrieve information.
```markdown
/status - Show current state
/context - Show context usage
/tasks - Show active tasks
```

#### 4. Utility Commands
Helper operations.
```markdown
/checkpoint - Save progress
/resume - Resume previous session
/clear - Clear conversation
```

## Quality Checklist

### Structural Quality
- [ ] Name is verb-first, single word if possible
- [ ] Description under 80 characters
- [ ] Arguments documented if any
- [ ] Examples provided

### Content Quality
- [ ] Delegates to agent/skill (doesn't implement)
- [ ] Context setup is minimal
- [ ] Error handling is clear
- [ ] Related commands mentioned

### Anti-Patterns Avoided
- [ ] No implementation logic in command
- [ ] No duplicate functionality with other commands
- [ ] No ambiguous naming
- [ ] No undocumented arguments

## Kailash Setup Command Strategy

### Current State
Kailash uses skills as commands via the Skill tool:
- `/01-core-sdk` - Core SDK patterns
- `/02-dataflow` - DataFlow patterns
- etc.

### Issue: Naming Convention
Numbered prefixes (`01-`, `02-`) aid organization but hurt memorability.

### Recommended Aliases
Create memorable aliases pointing to numbered skills:

| Alias | Points To | Use Case |
|-------|-----------|----------|
| `/sdk` | `/01-core-sdk` | Core SDK quick ref |
| `/db` | `/02-dataflow` | DataFlow patterns |
| `/api` | `/03-nexus` | Nexus deployment |
| `/ai` | `/04-kaizen` | Kaizen agents |
| `/mcp` | `/05-mcp` | MCP integration |
| `/test` | `/12-testing-strategies` | Testing patterns |
| `/validate` | `/17-gold-standards` | Compliance check |

### Implementation
```markdown
# .claude/commands/sdk.md
---
name: sdk
description: Core SDK quick patterns
---

Invoke the 01-core-sdk skill for Core SDK patterns.
```

## Recommended Commands for Kailash

### Development Commands
```
/sdk      - Core SDK patterns
/db       - DataFlow operations
/api      - Nexus deployment
/ai       - Kaizen agents
/test     - Run tests
/validate - Check compliance
```

### Workflow Commands
```
/plan     - Enter planning mode (invoke Plan agent)
/review   - Code review (invoke intermediate-reviewer)
/commit   - Create commit (invoke git-release-specialist)
/deploy   - Deploy (invoke deployment-specialist)
```

### Information Commands
```
/status   - Current task status (todo-manager)
/context  - Context usage
/docs     - Open relevant sdk-users docs
```

## Command vs Skill Decision

```
Use COMMAND when:
├── User will type this frequently
├── Name should be memorable (1-2 words)
├── Action is well-defined
└── Minimal/no arguments needed

Use SKILL when:
├── Contains substantial reference content
├── Needs detailed documentation
├── Multiple related patterns
└── Referenced by agents, not just users
```

## Template: Kailash Command

```markdown
---
name: command-name
description: Brief action description (verb-first)
---

# /command-name

[One sentence explaining what happens]

Invoke the [agent-name] agent for [specific task].

## Usage
```
/command-name           # Basic usage
/command-name [arg]     # With argument
```

## Related Commands
- `/related-cmd` - Related action
- `/another-cmd` - Another related action
```

## Current Gap

Kailash setup relies solely on numbered skills, missing the user-friendly command layer.

**Recommendation**: Create `commands/` directory with:
1. Memorable aliases for common skills
2. Workflow initiation commands
3. Utility commands for session management
