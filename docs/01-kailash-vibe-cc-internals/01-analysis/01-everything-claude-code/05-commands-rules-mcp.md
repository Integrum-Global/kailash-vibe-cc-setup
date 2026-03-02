# Everything Claude Code - Commands, Rules, and MCP Analysis

## Commands Analysis (23 Commands)

Commands in Everything Claude Code provide quick slash-command access to common workflows.

### Core Development Commands

| Command | Purpose | Agent Used |
|---------|---------|------------|
| `/tdd` | Enforce test-driven development | tdd-guide |
| `/plan` | Create implementation plan (waits for confirmation) | planner |
| `/code-review` | Comprehensive code review | code-reviewer |
| `/e2e` | Generate Playwright E2E tests | e2e-runner |
| `/build-fix` | Fix build/TypeScript errors (minimal diffs) | build-error-resolver |
| `/refactor-clean` | Dead code removal | refactor-cleaner |

### Learning & Verification Commands

| Command | Purpose | Description |
|---------|---------|-------------|
| `/learn` | Extract patterns mid-session | Longform guide pattern |
| `/checkpoint` | Save verification state | State persistence |
| `/verify` | Run verification loop | Continuous verification |
| `/eval` | Run evaluations | Eval harness |

### Setup & Configuration Commands

| Command | Purpose | Description |
|---------|---------|-------------|
| `/setup-pm` | Configure package manager | Detects npm/pnpm/yarn/bun |
| `/update-docs` | Update documentation | Doc sync |
| `/test-coverage` | Generate coverage reports | Test reporting |
| `/update-codemaps` | Update code maps | Code structure |

### Go-Specific Commands

| Command | Purpose | Agent Used |
|---------|---------|------------|
| `/go-review` | Go code review | go-reviewer |
| `/go-test` | Go TDD workflow | go-reviewer |
| `/go-build` | Fix Go build errors | go-build-resolver |

### Continuous Learning v2 Commands

| Command | Purpose | Description |
|---------|---------|-------------|
| `/instinct-status` | View learned instincts | Check learning progress |
| `/instinct-import` | Import instincts | Get patterns from others |
| `/instinct-export` | Export instincts | Share your patterns |
| `/evolve` | Cluster instincts into skills | Generate new configurations |

### Advanced Commands

| Command | Purpose | Description |
|---------|---------|-------------|
| `/orchestrate` | Multi-agent orchestration | Complex task coordination |
| `/skill-create` | Generate skills from git history | Local or GitHub App |

### Package Manager Detection Priority

The `/setup-pm` command follows this detection priority:

1. `CLAUDE_PACKAGE_MANAGER` environment variable
2. `.claude/package-manager.json` (project config)
3. `packageManager` field in `package.json`
4. Lock file detection:
   - `package-lock.json` → npm
   - `yarn.lock` → yarn
   - `pnpm-lock.yaml` → pnpm
   - `bun.lockb` → bun
5. `~/.claude/package-manager.json` (global config)
6. Fallback to first available

---

## Rules Analysis (8 Rules)

Rules are modular best practices documents that are ALWAYS followed.

### 1. security.md
**Critical security requirements**

- No hardcoded secrets
- SQL injection prevention
- XSS prevention
- CSRF protection
- Authentication requirements
- Authorization checks
- Rate limiting
- Secret management protocol

### 2. coding-style.md
**Code organization standards**

**CRITICAL PATTERN - Immutability**:
```typescript
// ALWAYS use spread operator
const updated = { ...obj, newProp: value };

// NEVER mutate directly
obj.newProp = value; // FORBIDDEN
```

**File Size Guidelines**:
- 200-400 lines: Typical
- 800 lines: Maximum

**Code Quality Checklist**:
- Error handling
- Input validation
- Type safety
- Clean architecture

### 3. testing.md
**Testing requirements**

**Coverage Requirements**:
- 80% minimum (MANDATORY)
- 100% for critical code (financial, auth, security)

**Test Types (ALL Required)**:
- Unit tests
- Integration tests
- E2E tests

**TDD Workflow**: MANDATORY

### 4. git-workflow.md
**Git and PR processes**

**Conventional Commits Format**:
```
type(scope): description

feat(auth): add OAuth2 support
fix(api): resolve rate limiting issue
docs(readme): update installation guide
```

**Pull Request Workflow**:
1. Analyze full commit history
2. Comprehensive summaries
3. Review before merge

**Feature Implementation Workflow**:
```
Plan → TDD → Review → Commit
```

### 5. agents.md
**Agent orchestration rules**

**When to Delegate**:
- Complex features → planner
- Architectural decisions → architect
- Code changes → code-reviewer (MANDATORY)
- New features → tdd-guide
- Security-sensitive → security-reviewer

**Parallel Execution**: Use for independent operations

**Multi-perspective Analysis**: Split roles across subagents

### 6. performance.md
**Model selection and context management**

- Token optimization strategies
- System prompt slimming
- Background process recommendations
- Context window management

### 7. hooks.md
**Hook system documentation**

- Hook types and events
- Auto-accept permissions guidance
- TodoWrite best practices

### 8. patterns.md
**Common workflow patterns**

- Reusable patterns
- Anti-patterns to avoid
- Best practice examples

### Rule Installation Locations

| Scope | Location | Applies To |
|-------|----------|------------|
| User | `~/.claude/rules/` | All projects |
| Project | `.claude/rules/` | Current project only |

**Important**: Rules are NOT distributed via plugins (upstream limitation)

---

## MCP Configuration Analysis (15+ Servers)

**File**: `mcp-configs/mcp-servers.json`

### Configured MCP Servers

| Server | Purpose | Type |
|--------|---------|------|
| **github** | GitHub operations (PRs, issues, repos) | HTTP |
| **firecrawl** | Web scraping and crawling | HTTP |
| **supabase** | Supabase database operations | HTTP |
| **memory** | Persistent memory across sessions | Stdio |
| **sequential-thinking** | Chain-of-thought reasoning | Stdio |
| **vercel** | Vercel deployments | HTTP |
| **railway** | Railway deployments | HTTP |
| **cloudflare-docs** | Cloudflare documentation | HTTP |
| **cloudflare-workers-builds** | Workers builds | HTTP |
| **cloudflare-workers-bindings** | Workers bindings | HTTP |
| **cloudflare-observability** | Logs and observability | HTTP |
| **clickhouse** | ClickHouse analytics | Stdio |
| **context7** | Live documentation lookup | HTTP |
| **magic** | Magic UI components | HTTP |
| **filesystem** | Filesystem operations | Stdio |

### MCP Context Warning

**CRITICAL**: Don't enable all MCPs at once

```
200k context → ~70k with too many MCPs enabled
```

**Rule of Thumb**:
- 20-30 MCPs configured
- <10 enabled per project
- <80 tools active at any time

### MCP Configuration Example

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["@bytebase/dbhub", "--dsn", "postgresql://..."],
      "env": {
        "DB_PASSWORD": "${DB_PASSWORD}"
      }
    }
  }
}
```

### MCP Tool Naming Pattern

`mcp__<server>__<tool>`

Examples:
- `mcp__memory__create_entities`
- `mcp__github__list_prs`
- `mcp__postgres__query`

### MCP in Hooks

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "mcp__memory__.*",
        "hooks": [{"type": "command", "command": "echo 'Memory operation'"}]
      }
    ]
  }
}
```

---

## Gap Analysis

### Strengths

**Commands**:
- Comprehensive coverage of dev workflow
- Language-specific commands (Go)
- Continuous learning integration
- Package manager auto-detection

**Rules**:
- Modular organization
- Clear enforcement (MANDATORY patterns)
- Coverage of security, testing, style
- Git workflow documentation

**MCP**:
- Wide variety of integrations
- Good deployment coverage (Vercel, Railway)
- Memory persistence
- Database access

### Missing

**Commands**:
- No Python-specific commands
- No Rust commands
- No mobile dev commands
- No cloud-specific commands (AWS, GCP)

**Rules**:
- No Python coding standards
- No mobile development rules
- No accessibility rules
- No performance benchmarking rules

**MCP**:
- Limited AI/ML integrations
- No AWS/GCP MCPs
- No Slack/Discord integrations
- No Jira/Linear integrations
