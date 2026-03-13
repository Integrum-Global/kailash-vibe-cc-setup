---
name: implement
description: "Load phase 03 (implement) for the current workspace. Repeat until all todos complete."
---

## What This Phase Does (present to user)

Build the project one task at a time from the approved roadmap. Each run of `/implement` completes one task. The AI writes code, tests it, reviews it for quality and security, then moves to the next task.

## Your Role (communicate to user)

You don't need to look at code. Your role is to answer questions when decisions come up during building — these will always be about what the product should do, not how it's coded. You can check progress anytime with `/ws`.

## Workspace Resolution

1. If `$ARGUMENTS` specifies a project name or todo, parse accordingly
2. Otherwise, use the most recently modified directory under `workspaces/` (excluding `instructions/`)
3. If no workspace exists, ask the user to create one first
4. Read all files in `workspaces/<project>/briefs/` for user context (this is the user's input surface)

## Phase Check

- Read files in `workspaces/<project>/todos/active/` to see what needs doing
- Read files in `workspaces/<project>/todos/completed/` to see what's done
- If `$ARGUMENTS` specifies a specific todo, focus on that one
- Otherwise, pick the next active todo
- Reference plans in `workspaces/<project>/02-plans/` for context

## Workflow

### NOTE: Run `/implement` repeatedly until all todos/active have been moved to todos/completed

### 1. Prepare todos

You MUST always use the todo-manager to create detailed todos for EVERY SINGLE TODO in `todos/000-master.md`.

- Review with agents before implementation
- Ensure that both FE and BE detailed todos exist, if applicable

### 2. Implement

Continue with the implementation of the next todo/phase using a team of agents, following procedural directives.

- Ensure that both FE and BE are implemented, if applicable

### 3. Quality standards

Always involve tdd-implementer, testing-specialists, value auditor, ai ui ux specialists, with any agents relevant to the work at hand.

- Test for rigor, completeness, and quality of output from both value and technical user perspectives
- Pre-existing failures often hint that you are missing something obvious and critical
  - Always address pre-existing failures — do not pass until all failures, warnings, hints are resolved
- Always identify the root causes of issues, and implement optimal, elegant fixes

### 4. Testing requirements

Ensure you test comprehensively as you implement, with all tests passing at 100%.

- No tests can be skipped (make sure docker is up and running)
- Do not rewrite tests just to get them passing — ensure it's not infrastructure issues causing errors
- Always test according to the intent of what we are trying to achieve and against users' expectations
  - Do not write simple naive technical assertions
  - Do not have stubs, hardcodes, simulations, naive fallbacks without informative logs
- If tests involve LLMs and are too slow, check if you are using local LLMs and switch to OpenAI
- If tests involve LLMs and are failing, check these errors first before skipping or changing logic:
  - Structured outputs are not coded properly
  - LLM agentic pipelines are not coded properly
  - Only after exhausting all input/output and pipeline errors, try with a larger model

### 5. LLM usage

When writing and testing agents, always utilize the LLM's capabilities instead of naive NLP approaches (keywords, regex, etc).

- Use ollama or openai (if ollama is too slow)
- Always check `.env` for api keys and model names to use in development
  - Always assume model names in memory are outdated — perform a web check on model names in `.env` before declaring them invalid

### 6. Communicate progress and surface decisions

When reporting to the user:

- **Progress**: State what users can now do, not what files changed. "Users can now reset their password via email" not "Added password reset endpoint and email template"
- **Decisions needed**: Present choices with impact. "Should password reset links expire after 1 hour or 24 hours? Shorter is more secure but less convenient for users who check email infrequently."
- **Scope changes**: If implementation reveals something not in the plan, explain what and why: "While building the signup flow, I noticed we don't have a way to handle duplicate emails. Should I add that now (adds ~30 minutes) or save it for later?"
- **Blockers**: Translate technical blockers into business language. Never present raw error messages.

### 7. Update docs and close todos

After completing each todo:

- Move it from `todos/active/` to `todos/completed/`
- Ensure every task is verified with evidence before closing

At the end of each implementation cycle, create and update documentation at the **project root** (not inside the workspace):

- `docs/` (complete detailed docs capturing every detail of the codebase)
  - This is the last resort document that agents use to find elusive and deep documentation
- `docs/00-authority/`
  - Authoritative documents that developers and codegen read first for full situational awareness
  - Ensure you create/update `README.md` (navigating authority documents) and `CLAUDE.md` (preloaded instructions)
- Use as many subdirectories and files as required, naming them sequentially 00-, 01- for easy referencing
- Focus on capturing the essence and intent — the 'what it is' and 'how to use it' — not status/progress/reports

**Note:** Project agents and skills (`.claude/agents/project/`, `.claude/skills/project/`) are created in phase 05 (`/codify`), not here. However, when implementation changes an API or adds a feature, update the corresponding **existing** skill files, rules, and hooks immediately to prevent drift. Do not defer corrections to `/codify` — that phase is for creating **new** project-specific artifacts, not for fixing stale existing ones.

### 8. Completion evidence

Before closing ANY todo, you MUST provide concrete evidence:

**For code changes:**

- [ ] File path(s) where work is stored
- [ ] All tests pass (unit, integration, e2e as applicable)
- [ ] Code review (intermediate-reviewer has reviewed)
- [ ] Security review (security-reviewer has reviewed)
- [ ] No regressions introduced

**For documentation changes:**

- [ ] File path(s) where work is stored
- [ ] Cross-references verified (all links resolve)
- [ ] Review completed (intermediate-reviewer)

A todo is NOT complete until evidence is provided. "Verified with evidence" means specific file paths, test results, and review attestations — not a general statement.

### 9. Decision log

When the user makes a decision during implementation, capture it:

```yaml
decision: [What was decided]
rationale: [Why — the reasoning]
alternatives_rejected: [What other options were considered]
date: [When]
initiative: [Which initiative]
```

Store decisions in the workspace for `/codify` to capture later.

## Agent Teams

Deploy these agents as a team for each implementation cycle:

**Core team (always):**

- **tdd-implementer** — Test-first development, red-green-refactor
- **testing-specialist** — 3-tier test strategy, NO MOCKING in Tier 2-3
- **intermediate-reviewer** — Code review after every file change (MANDATORY)
- **todo-manager** — Track progress, update todo status, verify completion with evidence

**Specialist (invoke ONE matching the current todo):**

- **pattern-expert** — Workflow patterns, node configuration
- **dataflow-specialist** — Database operations (if project uses DataFlow)
- **nexus-specialist** — API deployment (if project uses Nexus)
- **kaizen-specialist** — AI agents (if project uses Kaizen)
- **mcp-specialist** — MCP integration (if project uses MCP)

**Frontend team (when implementing frontend):**

- **uiux-designer** — Design system, visual hierarchy, responsive layouts
- **react-specialist** or **flutter-specialist** — Framework-specific implementation
- **ai-ux-designer** — AI interaction patterns (if AI-facing UI)
- **frontend-developer** — Responsive UI components

**Recovery (invoke when builds break):**

- **build-fix** — Fix build/type errors with minimal changes (NO architectural changes)

**Quality gate (once per todo, before closing):**

- **value-auditor** — Evaluate from user/buyer perspective, not just technical assertions
- **security-reviewer** — Security audit before any commit (MANDATORY)
