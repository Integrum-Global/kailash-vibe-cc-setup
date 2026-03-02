# Agent Cross-References

## Why Cross-References Matter

Without cross-references, agents work in isolation:
- No handoff to appropriate specialist
- Repeated work across agents
- No fallback to full documentation

Everything Claude Code explicitly documents agent relationships. Kailash agents should too.

## Cross-Reference Template

Add this section to the END of each agent file:

```markdown
## Related Agents
- **[agent-name]**: Hand off when [condition]
- **[agent-name]**: Consult for [specific expertise]

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/path/to/CLAUDE.md` - [Description]
```

## Agent Relationship Matrix

```
FROM Agent          →  TO Agent              CONDITION
─────────────────────────────────────────────────────────
deep-analyst        →  requirements-analyst  Need formal requirements
deep-analyst        →  framework-advisor     Architecture decision needed
requirements-analyst →  framework-advisor     Framework selection needed
framework-advisor   →  dataflow-specialist   DataFlow selected
framework-advisor   →  nexus-specialist      Nexus selected
framework-advisor   →  kaizen-specialist     Kaizen selected
framework-advisor   →  mcp-specialist        MCP integration needed
tdd-implementer     →  testing-specialist    Complex test strategy
pattern-expert      →  gold-standards-validator  Compliance check needed
intermediate-reviewer →  security-reviewer   Security-sensitive code
ANY                 →  build-fix             Build error occurs
ANY                 →  security-reviewer     Before commit
```

## Cross-References by Agent

### deep-analyst.md
```markdown
## Related Agents
- **requirements-analyst**: Hand off when formal requirements/ADRs needed
- **framework-advisor**: Hand off for architectural decisions
- **sdk-navigator**: Consult for documentation lookup

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/guides/analysis-patterns.md`
```

### requirements-analyst.md
```markdown
## Related Agents
- **deep-analyst**: Return for deeper failure analysis
- **framework-advisor**: Hand off for framework selection
- **todo-manager**: Hand off for task breakdown

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/guides/requirements-patterns.md`
- `sdk-users/instructions/adr-template.md`
```

### sdk-navigator.md
```markdown
## Related Agents
- **framework-advisor**: When framework decision needed
- **dataflow-specialist**: For DataFlow-specific queries
- **nexus-specialist**: For Nexus-specific queries
- **kaizen-specialist**: For Kaizen-specific queries
- **mcp-specialist**: For MCP-specific queries

## Full Documentation
This agent IS the documentation navigator. All sdk-users/ paths are available.
```

### framework-advisor.md
```markdown
## Related Agents
- **dataflow-specialist**: Hand off when DataFlow selected
- **nexus-specialist**: Hand off when Nexus selected
- **kaizen-specialist**: Hand off when Kaizen selected
- **mcp-specialist**: Hand off when MCP integration needed
- **pattern-expert**: Consult for workflow patterns

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/apps/dataflow/CLAUDE.md`
- `sdk-users/apps/nexus/CLAUDE.md`
- `sdk-users/apps/kaizen/CLAUDE.md`
- `.claude/skills/05-mcp/SKILL.md`
```

### dataflow-specialist.md
```markdown
## Related Agents
- **framework-advisor**: Return if different framework needed
- **testing-specialist**: For DataFlow test patterns
- **pattern-expert**: For workflow integration
- **deployment-specialist**: For production deployment

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/apps/dataflow/CLAUDE.md` (2,900+ lines)
- `sdk-users/apps/dataflow/guides/` - Specific guides
```

### nexus-specialist.md
```markdown
## Related Agents
- **framework-advisor**: Return if different framework needed
- **dataflow-specialist**: For database integration
- **mcp-specialist**: For MCP channel integration
- **deployment-specialist**: For production deployment

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/apps/nexus/CLAUDE.md`
```

### kaizen-specialist.md
```markdown
## Related Agents
- **framework-advisor**: Return if different framework needed
- **pattern-expert**: For workflow patterns
- **mcp-specialist**: For agent-tool integration
- **testing-specialist**: For agent testing

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/apps/kaizen/CLAUDE.md` (1,900+ lines)
```

### mcp-specialist.md
```markdown
## Related Agents
- **framework-advisor**: For framework integration
- **kaizen-specialist**: For AI agent integration
- **nexus-specialist**: For multi-channel deployment
- **security-reviewer**: For MCP security review

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/apps/mcp/CLAUDE.md`
- `.claude/skills/05-mcp/SKILL.md`
```

### pattern-expert.md
```markdown
## Related Agents
- **framework-advisor**: For framework selection
- **dataflow-specialist**: For DataFlow-specific patterns
- **gold-standards-validator**: For pattern compliance
- **testing-specialist**: For pattern testing

## Full Documentation
When this guidance is insufficient, consult:
- `.claude/skills/01-core-sdk/SKILL.md`
- `.claude/skills/09-workflow-patterns/`
```

### tdd-implementer.md
```markdown
## Related Agents
- **testing-specialist**: For complex test strategy
- **pattern-expert**: For implementation patterns
- **gold-standards-validator**: For test compliance
- **build-fix**: When build fails during TDD

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/3-development/testing/CLAUDE.md`
- `.claude/skills/12-testing-strategies/SKILL.md`
```

### intermediate-reviewer.md
```markdown
## Related Agents
- **security-reviewer**: For security-sensitive changes
- **gold-standards-validator**: For compliance review
- **pattern-expert**: For pattern review
- **testing-specialist**: For test review

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/7-gold-standards/CLAUDE.md`
```

### gold-standards-validator.md
```markdown
## Related Agents
- **pattern-expert**: For pattern questions
- **testing-specialist**: For test validation
- **security-reviewer**: For security compliance
- **intermediate-reviewer**: For general review

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/7-gold-standards/CLAUDE.md`
- `.claude/skills/17-gold-standards/SKILL.md`
```

### testing-specialist.md
```markdown
## Related Agents
- **tdd-implementer**: For TDD guidance
- **e2e-runner**: For E2E testing
- **gold-standards-validator**: For test compliance
- **documentation-validator**: For doc testing

## Full Documentation
When this guidance is insufficient, consult:
- `sdk-users/3-development/testing/CLAUDE.md`
- `.claude/skills/12-testing-strategies/SKILL.md`
```

### Frontend Specialists
```markdown
## Related Agents
- **uiux-designer**: For design review
- **testing-specialist**: For frontend testing
- **pattern-expert**: For state management patterns
- **deployment-specialist**: For frontend deployment

## Full Documentation
When this guidance is insufficient, consult:
- `.claude/skills/11-frontend-integration/`
- `sdk-users/guides/frontend-patterns.md`
```

### Management Agents (todo-manager, gh-manager, git-release-specialist)
```markdown
## Related Agents
- **intermediate-reviewer**: For code review before PR
- **security-reviewer**: For security check before release
- **deployment-specialist**: For deployment coordination

## Full Documentation
When this guidance is insufficient, consult:
- `.claude/skills/10-deployment-git/`
```

## Implementation Steps

1. Open each agent file
2. Add "Related Agents" section at end
3. Add "Full Documentation" section after Related Agents
4. Verify cross-references are accurate (agent names exist)
5. Test handoff in Claude session
