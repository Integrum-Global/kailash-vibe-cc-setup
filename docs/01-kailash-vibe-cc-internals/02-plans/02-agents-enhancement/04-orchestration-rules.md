# Agent Orchestration Rules

## Overview

Everything Claude Code enforces mandatory delegations via `rules/agents.md`. Kailash currently has no such enforcement, making quality gates optional.

This plan creates `.claude/rules/agents.md` to enforce:
1. Code review after ANY change
2. Security review before ANY commit
3. Framework specialist consultation
4. Parallel execution for independent operations

## File: `.claude/rules/agents.md`

```markdown
# Agent Orchestration Rules

## Purpose

These rules define MANDATORY agent delegations. They are NOT optional - Claude Code MUST follow these rules.

## MANDATORY Delegations

### Rule 1: After ANY Code Change

**Trigger**: ANY file is modified via Edit or Write tool
**Action**: MUST invoke intermediate-reviewer

```
WHEN: Edit or Write tool completes successfully
THEN: Immediately delegate to intermediate-reviewer
      with the modified file path(s)
```

**Rationale**: Every change needs review. No exceptions.

### Rule 2: Before ANY Commit

**Trigger**: About to run `git commit`
**Action**: MUST invoke security-reviewer first

```
WHEN: User requests commit OR git commit about to execute
THEN: First delegate to security-reviewer
      to check ALL staged files
      ONLY proceed with commit if no CRITICAL findings
```

**Rationale**: Security issues must be caught before commit.

### Rule 3: For Complex Features

**Trigger**: New feature request or significant change
**Action**: MUST follow analysis chain

```
WHEN: Request involves:
      - New functionality
      - Architectural changes
      - Multi-file changes
      - Framework integration
THEN: Follow chain:
      deep-analyst → requirements-analyst → framework-advisor
      ONLY then proceed to implementation
```

**Rationale**: Understanding before coding.

### Rule 4: For Framework-Specific Work

**Trigger**: Work involves Kailash framework
**Action**: MUST consult framework specialist

```
WHEN: Work involves:
      - Database operations → dataflow-specialist
      - API/platform deployment → nexus-specialist
      - AI agents → kaizen-specialist
      - MCP integration → mcp-specialist
THEN: Consult specialist BEFORE implementation
```

**Rationale**: Framework expertise prevents mistakes.

### Rule 5: Parallel Execution

**Trigger**: Multiple independent operations needed
**Action**: MUST use parallel execution

```
WHEN: Operations are:
      - Multiple file reads (not dependent on each other)
      - Independent searches
      - Non-dependent analyses
THEN: Execute in parallel using Task tool
      with multiple concurrent agents
```

**Rationale**: Efficiency and speed.

## PROHIBITED Actions

### Prohibition 1: Skip Code Review
```
MUST NOT: Proceed to next task without code review
MUST NOT: Mark task complete without review
```

### Prohibition 2: Commit Without Security Review
```
MUST NOT: Run git commit without security-reviewer
MUST NOT: Push without final review
```

### Prohibition 3: Framework Work Without Specialist
```
MUST NOT: Write DataFlow code without dataflow-specialist
MUST NOT: Write Nexus code without nexus-specialist
MUST NOT: Write Kaizen code without kaizen-specialist
MUST NOT: Write MCP code without mcp-specialist
```

### Prohibition 4: Sequential When Parallel Possible
```
MUST NOT: Read files sequentially when they're independent
MUST NOT: Run searches one-by-one when they can be parallel
```

## Enforcement

### Via Hooks (Automated)
- PostToolUse hook can remind about code review
- PreToolUse hook on git commit can require security review

### Via Agent Behavior (Manual)
- Agents should self-check these rules
- Agents should remind when rules are violated

## Exceptions

Exceptions require EXPLICIT user approval:
- "Skip code review for this change"
- "Commit without security review (I'll review manually)"
- "Implement without specialist (I understand the risk)"

Document exceptions in commit message or PR description.

## Multi-Perspective Analysis

For architectural decisions, use MULTIPLE viewpoints:

```
Architectural Decision Required:
├── framework-advisor: Which framework?
├── pattern-expert: Which patterns?
├── testing-specialist: How to test?
├── security-reviewer: Security implications?
└── deployment-specialist: Deployment implications?
```

## Quality Gate Checkpoints

### Checkpoint 1: After Planning
- [ ] deep-analyst complete
- [ ] requirements-analyst complete
- [ ] framework-advisor recommendations received

### Checkpoint 2: After Implementation
- [ ] Code written
- [ ] intermediate-reviewer approved
- [ ] Tests written

### Checkpoint 3: Before Commit
- [ ] security-reviewer approved
- [ ] No CRITICAL findings
- [ ] All tests pass

### Checkpoint 4: Before Push/PR
- [ ] All checkpoints passed
- [ ] Documentation updated (if needed)
- [ ] CHANGELOG updated (if release)
```

## Integration with Hooks

These rules can be partially enforced via hooks:

### PostToolUse Hook Enhancement

```javascript
// In auto-format.js or separate hook
// After Edit/Write, remind about code review

if (process.env.HOOK_EVENT_NAME === 'PostToolUse') {
  console.log(JSON.stringify({
    continue: true,
    hookSpecificOutput: {
      reminder: 'RULE: Code review required for this change. Delegate to intermediate-reviewer.'
    }
  }));
}
```

### PreToolUse Hook for Git Commit

```javascript
// validate-bash-command.js enhancement
if (/git\s+commit/.test(command)) {
  return {
    continue: true,
    exitCode: 0,
    message: 'RULE: Security review required before commit. Has security-reviewer been invoked?'
  };
}
```

## Verification

After implementing rules:

1. In Claude session, make a code change
2. Verify code review is prompted
3. Attempt git commit
4. Verify security review is prompted
5. Request framework work
6. Verify specialist is consulted

## Success Metrics

| Metric | Before | Target |
|--------|--------|--------|
| Code reviews performed | Ad-hoc | 100% |
| Security reviews before commit | None | 100% |
| Specialist consultations | Ad-hoc | 100% for framework work |
| Parallel execution | Rare | Always when possible |
