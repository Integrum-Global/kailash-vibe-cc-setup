# Agent Philosophy and Quality Guide

## First Principles

### What Agents ARE
- **Policy Orchestrators**: Define WHAT to do and WHEN, not HOW
- **Decision Makers**: Apply judgment to determine appropriate actions
- **Delegators**: Know which skills/tools to invoke for specific tasks
- **Fallback Handlers**: Know when to consult full documentation

### What Agents are NOT
- **Implementation Details**: Should not contain step-by-step code
- **Documentation Repositories**: Should not duplicate reference material
- **Skill Replacements**: Should delegate to skills for task specifics

## The Agent Contract

```
INPUT: User request requiring specialized expertise
       ↓
AGENT RESPONSIBILITIES:
1. Understand the request context
2. Apply policy/process rules
3. Decide which skills to invoke
4. Determine when full docs needed
5. Orchestrate multi-step workflows
       ↓
OUTPUT: Completed task or clear handoff
```

## Structure Standards

### Required Frontmatter
```yaml
---
name: kebab-case-name
description: One sentence. Use when [trigger condition]. (max 120 chars)
tools: Tool1, Tool2, Tool3  # CRITICAL: Must declare tools used
model: opus|sonnet|haiku    # Match complexity to model cost
---
```

### Content Structure (Recommended Order)
```markdown
# [Agent Name]

You are a [role] specialist for [domain].

## Responsibilities
[What this agent does - 3-5 bullet points]

## Critical Rules
[Non-negotiable constraints - numbered list]

## Process
[High-level workflow - numbered steps]

## Skill References
[Which skills to invoke and when]

## Fallback Guidance
[When to consult full documentation]
```

## Quality Criteria

### Length Guidelines
| Quality | Lines | Symptoms |
|---------|-------|----------|
| Too Short (<80) | Missing critical guidance | Agent makes poor decisions |
| Optimal (100-300) | Focused policies | Clear, effective orchestration |
| Too Long (>400) | Detail leakage | Slow, confused responses |

### Content Balance
```
Ideal Distribution:
├── Role Definition:     10%
├── Responsibilities:    20%
├── Critical Rules:      25%
├── Process Steps:       25%
├── Skill References:    15%
└── Fallback Guidance:   5%
```

## Quality Checklist

### Structural Quality
- [ ] Frontmatter includes name, description, tools, model
- [ ] Description under 120 characters
- [ ] Tools explicitly declared (not implicit)
- [ ] Model matches task complexity

### Content Quality
- [ ] Role clearly defined in first paragraph
- [ ] Responsibilities limited to 3-5 items
- [ ] Critical rules are truly critical (not nice-to-haves)
- [ ] Process steps are high-level (not implementation details)
- [ ] Cross-references to related agents included
- [ ] Skill invocation guidance present
- [ ] Fallback to documentation path defined

### Anti-Patterns Avoided
- [ ] No implementation code in agent body
- [ ] No duplicated documentation content
- [ ] No vague responsibilities ("help with things")
- [ ] No model specification mismatch (haiku for complex tasks)

## Quality Issues in Current Kailash Setup

### Review Score: 8.5/10

**Strengths:**
- Clear role definitions
- Good responsibility structure
- Framework-specific expertise well-documented

**Issues Found:**

#### 1. Missing Tool Declarations (CRITICAL)
```yaml
# CURRENT (INCOMPLETE)
---
name: dataflow-specialist
description: Database operations specialist
---

# CORRECT
---
name: dataflow-specialist
description: Database operations specialist. Use for DataFlow v0.10.15+ implementations.
tools: Read, Write, Edit, Bash, Grep, Glob, Task
model: opus
---
```

**Impact**: Claude may not know which tools agent can use.

#### 2. Missing Cross-References
Current agents don't reference related agents for handoff.

```markdown
# ADD to each agent:
## Related Agents
- **dataflow-specialist**: Hand off for database operations
- **testing-specialist**: Hand off for test creation
- **gold-standards-validator**: Invoke for compliance checks
```

#### 3. Inconsistent Fallback Guidance
Some agents specify sdk-users paths, others don't.

```markdown
# STANDARDIZE in each agent:
## Full Documentation
When this skill's guidance is insufficient, consult:
- `sdk-users/apps/dataflow/CLAUDE.md` - Complete DataFlow reference
- `sdk-users/3-development/testing/CLAUDE.md` - Testing strategies
```

## Agent Categories and Model Selection

### Analysis Agents (Use: opus)
Complex reasoning, multi-perspective analysis required.
- deep-analyst
- requirements-analyst
- framework-advisor

### Implementation Agents (Use: opus or sonnet)
Code generation, pattern application.
- tdd-implementer
- pattern-expert
- dataflow-specialist

### Validation Agents (Use: sonnet)
Rule checking, compliance verification.
- gold-standards-validator
- intermediate-reviewer
- testing-specialist

### Utility Agents (Use: haiku)
Simple, well-defined tasks.
- todo-manager
- gh-manager
- git-release-specialist

## Template: Kailash Framework Specialist

```markdown
---
name: [framework]-specialist
description: [Framework] implementation specialist for Kailash SDK. Use when implementing [specific feature].
tools: Read, Write, Edit, Bash, Grep, Glob, Task
model: opus
---

You are a [Framework] specialist with deep expertise in Kailash SDK's [framework] module.

## Responsibilities
1. Guide [framework]-specific implementations
2. Ensure pattern compliance with sdk-users documentation
3. Validate against gold standards
4. Advise on architectural decisions within [framework]

## Critical Rules
1. ALWAYS consult sdk-users/apps/[framework]/CLAUDE.md first
2. NEVER deviate from documented patterns without explicit justification
3. Use real infrastructure testing (NO MOCKING in Tiers 2-3)
4. Follow the 4-param pattern for node configuration

## Process
1. Understand the requirement
2. Check sdk-users for existing patterns
3. Identify applicable templates
4. Guide implementation with specific references
5. Validate against gold standards

## Skill References
- `/[##]-[framework]` - Quick patterns and common operations
- `/17-gold-standards` - Mandatory compliance patterns

## Related Agents
- **pattern-expert**: For core workflow patterns
- **testing-specialist**: For test implementation
- **gold-standards-validator**: For compliance verification

## Full Documentation
When guidance here is insufficient:
- `sdk-users/apps/[framework]/CLAUDE.md` - Complete reference
- `sdk-users/7-gold-standards/` - Compliance requirements
```

## Improvement Actions

### Immediate (All Agents)
1. Add `tools:` to frontmatter
2. Add `model:` specification
3. Add "Related Agents" section
4. Add "Full Documentation" section

### Short-term
1. Audit each agent for detail leakage
2. Extract implementation details to skills
3. Standardize section ordering

### Long-term
1. Create agent interaction tests
2. Implement agent coverage metrics
3. Add automated frontmatter validation
