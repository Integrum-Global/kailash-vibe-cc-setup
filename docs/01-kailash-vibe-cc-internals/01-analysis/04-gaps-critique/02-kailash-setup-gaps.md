# Kailash Setup - Gaps and Critique

## Critical Gaps

### 1. No Hooks Infrastructure

**Gap**: Zero hooks configuration. No automation via tool lifecycle events.

**Impact**:
- No automatic formatting after file edits
- No validation before tool execution
- No session state persistence
- No continuous observation for learning
- No git push review reminders
- No dev server management

**Evidence**: No hooks.json, no scripts/hooks/ directory, no hook references in settings.

**What's Missing**:
```json
// Everything CC has:
{
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...],
    "SessionStart": [...],
    "SessionEnd": [...],
    "PreCompact": [...]
  }
}
```

**Kailash has**: Nothing.

**Recommendation**: Add hooks for:
- Auto-formatting (Prettier, Black)
- TypeScript/Python type checking
- Git workflow reminders
- Session state management
- Long-running command handling

### 2. No Continuous Learning System

**Gap**: No mechanism to learn from usage patterns.

**Impact**:
- Same mistakes repeated
- No personalization to user habits
- No pattern evolution
- No instinct accumulation

**Evidence**: No equivalent to:
- continuous-learning/ skill
- continuous-learning-v2/ skill
- observations.jsonl
- instincts/ directory
- /evolve, /instinct-* commands

**Recommendation**: Implement hooks-based observation with pattern extraction.

### 3. No Explicit MCP Configuration

**Gap**: MCPs handled by mcp-specialist agent but no pre-configured servers.

**Impact**:
- Users must configure MCPs manually
- No context budget warnings (200k→70k)
- No recommended MCP sets per project type
- Missing integrations (GitHub, memory, sequential-thinking)

**Evidence**:
- No mcp-configs/ directory
- No mcp-servers.json
- No MCP warnings in CLAUDE.md

**Recommendation**:
1. Add mcp-configs/ with common configurations
2. Document MCP context impact
3. Create project-type MCP recommendations

### 4. Limited Language-Specific Coverage

**Gap**: Agents and skills are Kailash SDK-specific. No Go, Java, Rust, pure Python patterns.

**Impact**:
- No guidance for non-Kailash projects
- Skills not transferable to other work
- Missing common language idioms

**Evidence**: All 17 skill categories are Kailash-focused:
- 01-core-sdk (Kailash)
- 02-dataflow (Kailash)
- 03-nexus (Kailash)
- 04-kaizen (Kailash)
- etc.

**Trade-off**: This is intentional specialization, not a flaw. But users working on non-Kailash projects have no support.

**Recommendation**: Add optional general language skills:
- Python coding standards
- TypeScript patterns
- Go idioms (if needed)

### 5. No Security-Focused Agent

**Gap**: No dedicated security reviewer like Everything CC's security-reviewer.

**Impact**:
- Security checks not enforced before commits
- OWASP Top 10 coverage not systematic
- No secrets detection automation
- Security is implicit, not explicit

**Evidence**:
- gold-standards-validator checks compliance but not security
- No pre-commit security gate
- No security.md rule equivalent

**Recommendation**:
1. Add security-reviewer agent
2. Create security validation skill
3. Add pre-commit security check to SOP

---

## Moderate Gaps

### 6. No Mandatory Code Review Enforcement

**Gap**: No rule that code-reviewer MUST be used after every change.

**Impact**:
- Easy to skip code review
- Quality inconsistent
- Technical debt accumulates

**Comparison**: Everything CC has explicit rule in agents.md: "code-reviewer MUST be used after ALL code changes"

**Recommendation**: Add explicit agent orchestration rules.

### 7. No Build Error Specialist

**Gap**: No agent focused on fixing build errors with minimal diffs.

**Impact**:
- Build error fixes may be over-engineered
- No "minimal change" philosophy enforced
- TypeScript errors may trigger refactoring

**Comparison**: Everything CC has build-error-resolver with NO architectural changes policy.

**Recommendation**: Add build-fix agent with minimal diff mandate.

### 8. No Context Management Documentation

**Gap**: No explicit guidance on context window management.

**Impact**:
- Users may enable too many MCPs
- No compaction strategy documented
- Context exhaustion surprises

**Comparison**: Everything CC explicitly warns: "200k → ~70k with too many MCPs"

**Recommendation**: Add context management section to CLAUDE.md.

### 9. No Skill-Based Learning Commands

**Gap**: No /learn, /checkpoint, /evolve equivalents.

**Impact**:
- No mid-session pattern extraction
- No state persistence commands
- No knowledge evolution

**Recommendation**: Add learning-focused skills/commands.

### 10. Commands Less Memorable Than Everything CC

**Gap**: Skills are numbered (01-core-sdk, 02-dataflow) vs named (/tdd, /plan).

**Impact**:
- Harder to remember skill names
- Less intuitive invocation
- Numbered system requires lookup

**Trade-off**: Numbered system provides ordering and organization.

**Recommendation**: Add memorable aliases for common skills.

---

## Minor Gaps

### 11. No Package Manager Detection

**Gap**: No /setup-pm equivalent for npm/pnpm/yarn/bun detection.

### 12. No Cross-Platform Scripts

**Gap**: No scripts/ directory with Node.js utilities.

### 13. No Traditional Chinese Translation

**Gap**: Everything CC has complete zh-TW translation.

### 14. No Plugin Distribution

**Gap**: Not packaged as Claude Code plugin for easy installation.

### 15. No E2E Runner Agent

**Gap**: No Playwright-focused agent like Everything CC's e2e-runner.

---

## Architectural Critique

### SOP May Be Too Rigid

**Issue**: 5-phase workflow may not fit all projects.

**Concerns**:
1. Small fixes don't need full analysis phase
2. Hotfixes skip planning
3. Exploration tasks don't fit phases
4. Research projects have different flow

**Trade-off**: Structure vs Flexibility. SOP ensures quality but may slow small changes.

**Recommendation**: Add "fast path" for small changes.

### SDK-Users as Single Point of Failure

**Issue**: All knowledge flows through sdk-users documentation.

**Concerns**:
1. Documentation updates require sdk-users changes
2. Skills become stale if sdk-users not updated
3. Large context load when full docs needed
4. Version mismatches between skills and sdk-users

**Trade-off**: Centralization vs Distribution. Single source is consistent but creates dependency.

**Recommendation**: Add versioning checks between skills and sdk-users.

### 18 Agents May Cause Confusion

**Issue**: Many specialized agents may overlap or confuse delegation.

**Questions**:
- When to use deep-analyst vs requirements-analyst?
- When to use pattern-expert vs tdd-implementer?
- When to use react-specialist vs frontend-developer?

**Trade-off**: Specialization vs Simplicity.

**Recommendation**: Add clearer decision tree in README.

### Guides Directory Partially Redundant

**Issue**: 11 guides in .claude/guides/ overlap with sdk-users documentation.

**Examples**:
- flutter-design-system.md vs sdk-users/apps/ docs
- uiux-design-principles.md vs design guidance in skills

**Trade-off**: Quick access vs Duplication.

**Recommendation**: Consolidate or clearly differentiate purposes.

---

## Strength Assessment

Despite gaps, Kailash Setup excels at:

1. **Framework Mastery**: Deep DataFlow, Nexus, Kaizen knowledge
2. **Documentation Depth**: 89KB+ per framework
3. **Structured Workflow**: Complete 5-phase SOP
4. **Real Testing**: NO MOCKING in Tiers 2-3
5. **Full Stack Coverage**: Backend + frontend (React, Flutter) + DevOps
6. **AI Development**: Built-in Kaizen agent support
7. **Error Documentation**: 60+ error codes with solutions
8. **Industry Patterns**: Finance, healthcare, logistics templates

---

## Priority Recommendations

### High Priority
1. Add hooks infrastructure (formatting, validation, session management)
2. Add explicit MCP configurations with context warnings
3. Add security-reviewer agent
4. Add agent orchestration rules (mandatory review)

### Medium Priority
5. Add build-fix agent with minimal diff policy
6. Document context management strategies
7. Add memorable skill aliases
8. Add continuous learning mechanism

### Low Priority
9. Add package manager detection
10. Create cross-platform utility scripts
11. Package as Claude Code plugin
12. Add fast path for small changes
