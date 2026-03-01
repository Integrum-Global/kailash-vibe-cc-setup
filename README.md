# Kailash Vibe CC Setup

<p align="center">
  <img src="https://img.shields.io/badge/platform-Claude%20Code-7C3AED.svg" alt="Claude Code">
  <img src="https://img.shields.io/badge/agents-29-blue.svg" alt="29 Agents">
  <img src="https://img.shields.io/badge/skills-25-green.svg" alt="25 Skills">
  <img src="https://img.shields.io/badge/hooks-8-orange.svg" alt="8 Hooks">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="Apache 2.0">
</p>

<p align="center">
  <strong>Cognitive Orchestration for Codegen (COC)</strong>
</p>

<p align="center">
  A five-layer cognitive architecture for <a href="https://docs.anthropic.com/en/docs/claude-code">Anthropic's Claude Code</a> that replaces unstructured "vibe coding" with institutionally aware, self-enforcing, continuously learning AI code generation. Built natively for <a href="https://github.com/Integrum-Global/kailash_sdk">Kailash SDK</a> development.
</p>

---

## The Problem: Why Vibe Coding Fails

"Vibe coding" -- describing what you want and letting AI write code -- sounds magical. In practice, it produces five systemic failures:

1. **Amnesia**: The AI forgets your conventions mid-session when context is compressed
2. **Convention Drift**: Each file uses different patterns from the AI's training data
3. **Framework Ignorance**: The AI has never seen your internal frameworks and generates plausible but wrong code
4. **Quality Erosion**: Code quality degrades over the course of a session -- more TODOs, more stubs, more silent fallbacks
5. **Security Blindness**: Hardcoded API keys, SQL injection, `eval()` on user input -- generated faster than any human can review

The root cause is not the AI model. It's the **absence of institutional knowledge in the coding loop**.

---

## The Solution: Cognitive Orchestration for Codegen

COC encodes your organization's intent, context, guardrails, and instructions directly into the AI's operating environment. Instead of one generalist AI guessing at patterns, COC provides five interlocking layers:

```
Your Natural Language Request
         |
   Intent    (29 Agents)     Who should handle this?
         |
   Context   (25 Skills)     What does the AI need to know?
         |
   Guardrails (8 Rules       What must the AI never do?
              + 8 Hooks)     [Deterministic enforcement]
         |
   Instructions (CLAUDE.md   What should the AI prioritize?
              + 12 Commands)
         |
   Learning  (Observe ->     How does the system improve?
              Instinct ->
              Evolve)
         |
   Production-Ready Code
```

---

## Architecture

### Layer 1: Intent (Agents)

29 specialized AI sub-agents organized into 7 development phases. Each agent is a Markdown file with YAML frontmatter defining its name, tools, and model tier.

| Phase          | Agents                                                                                                                                            | Purpose                                 |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| Analysis       | `deep-analyst`, `requirements-analyst`, `sdk-navigator`, `framework-advisor`                                                                      | Understand the problem                  |
| Planning       | `todo-manager`, `gh-manager`, `intermediate-reviewer`                                                                                             | Break down and track work               |
| Implementation | `tdd-implementer`, `pattern-expert`, `dataflow-specialist`, `nexus-specialist`, `kaizen-specialist`, `mcp-specialist`, `gold-standards-validator` | Build with the right patterns           |
| Testing        | `testing-specialist`, `documentation-validator`                                                                                                   | Verify with real infrastructure         |
| Deployment     | `deployment-specialist`                                                                                                                           | Docker, Kubernetes                      |
| Release        | `git-release-specialist`, `security-reviewer`                                                                                                     | Pre-commit validation, OWASP audit      |
| Final Review   | `intermediate-reviewer`                                                                                                                           | Quality gate (repeats 3x across phases) |

Agents declare their model tier: analysis agents run on Opus (deep reasoning), review agents run on Sonnet (fast, cost-efficient). Agents cannot invoke other agents -- all coordination flows through the main orchestrator.

### Layer 2: Context (Skills)

25 directories containing 100+ Markdown files of organized domain knowledge, following a progressive disclosure model:

```
SKILL.md           10-50 lines    Quick patterns
Topic files        50-250 lines   Specific domains
Full SDK docs      Unlimited      Deep reference
```

**Skill domains**: Core SDK, DataFlow, Nexus, Kaizen, MCP, cheatsheets, development guides, 110+ node reference, industry workflow templates, deployment, frontend integration (React + Flutter), 3-tier testing, architecture decisions, code templates, error troubleshooting, validation patterns, security patterns, Flutter patterns, interactive widgets, enterprise AI UX, conversation UX, UI/UX design principles, value audit, AI interaction patterns.

Each agent reads from its associated skill directory. One source of truth per topic -- no contradictions, no drift.

### Layer 3: Guardrails (Rules + Hooks)

Two enforcement mechanisms working together:

**Rules** (8 Markdown files -- soft enforcement, AI interpretation):

| Rule              | Key Constraint                                                               |
| ----------------- | ---------------------------------------------------------------------------- |
| `agents.md`       | Code review after EVERY file change; security review before EVERY commit     |
| `testing.md`      | NO MOCKING in Tier 2-3 tests; TDD mandatory; 100% coverage for auth/security |
| `security.md`     | No hardcoded secrets; parameterized queries only; no `eval()` on user input  |
| `patterns.md`     | `runtime.execute(workflow.build())` -- exact pattern required                |
| `env-models.md`   | `.env` is single source of truth for all API keys and model names            |
| `no-stubs.md`     | No TODO/FIXME/HACK in production code; implement gaps, don't document them   |
| `git.md`          | Conventional commits; no direct push to main; atomic commits                 |
| `e2e-god-mode.md` | Create all missing test records; implement missing endpoints; never skip     |

**Hooks** (8 Node.js scripts -- hard enforcement, deterministic):

| Hook                            | Event            | What It Does                                                              |
| ------------------------------- | ---------------- | ------------------------------------------------------------------------- |
| `session-start.js`              | SessionStart     | Validates `.env` model-key pairings, detects active framework             |
| `user-prompt-rules-reminder.js` | UserPromptSubmit | **Anti-amnesia**: re-injects core rules on every single user message      |
| `validate-bash-command.js`      | PreToolUse       | BLOCKS `rm -rf /`, fork bombs; WARNS on `git push` without review         |
| `validate-workflow.js`          | PostToolUse      | BLOCKS hardcoded models (Rust); detects 13 API key patterns, stub markers |
| `auto-format.js`                | PostToolUse      | Runs `black` / `prettier` automatically on every write                    |
| `pre-compact.js`                | PreCompact       | Saves framework state checkpoint before context compression               |
| `session-end.js`                | SessionEnd       | Persists session stats for learning system                                |
| `stop.js`                       | Stop             | Emergency state save on termination                                       |

**Defense in depth**: Critical rules have 5-8 independent enforcement layers. Example -- "never hardcode model names" is enforced by: `CLAUDE.md`, `env-models.md` rule, `user-prompt-rules-reminder.js` (every turn), `session-start.js` (session start), and `validate-workflow.js` (every file write). If any four fail, the fifth catches it.

### Layer 4: Instructions (CLAUDE.md + Commands)

The root `CLAUDE.md` is auto-loaded every session. It uses deliberate prompt engineering techniques:

- **Directive escalation**: Soft guidance first, then "ABSOLUTE RULES (NEVER VIOLATE)"
- **Positive/negative anchoring**: Each rule stated as what to do AND what violations look like
- **Framework context injection**: Complete technical reference for all four frameworks embedded directly
- **Relationship mapping**: Prevents AI from hallucinating false independence between frameworks

12 slash commands (`/sdk`, `/db`, `/api`, `/ai`, `/test`, `/validate`, `/design`, `/learn`, `/evolve`, `/checkpoint`, `/i-audit`, `/i-harden`) serve as context-efficient entry points into skill directories.

### Layer 5: Learning (Closed Loop)

A three-stage observation-to-evolution pipeline:

```
Session Activity  -->  Observations (JSONL)
                           |
                    Instinct Processor
                    (Frequency 40% + Success 30% +
                     Recency 20% + Consistency 10%)
                           |
                    Instinct Evolver
                           |
              +------------+------------+
              |            |            |
         0.85+ conf   0.90+ conf   0.95+ conf
         20+ obs      30+ obs      50+ obs
              |            |            |
          New Skill    New Command   New Agent
```

The system discovers recurring patterns from usage and automatically generates new skills, commands, and agents. It gets smarter with every coding session.

---

## Quick Start

### Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- Node.js 18+ (for hooks)

### Installation

```bash
# Clone this repository
git clone https://github.com/Integrum-Global/kailash-vibe-cc-setup.git
cd kailash-vibe-cc-setup

# Create your .env file
cp .env.example .env
# Edit .env with your API keys and model preferences

# Start Claude Code
claude
```

On first session, the `session-start.js` hook automatically validates your `.env` configuration, detects your active framework, and initializes the learning system.

### Usage

Just describe what you want. COC handles the rest:

```
You: "Create a user registration system with DataFlow for the database,
      Nexus for the API, and integration tests"

COC:  1. Loads DataFlow + Nexus skills automatically
      2. Delegates to dataflow-specialist and nexus-specialist agents
      3. Writes code following all SDK patterns (hooks validate every write)
      4. Writes integration tests with real infrastructure (NO MOCKING enforced)
      5. Runs security-reviewer before any commit
      6. Produces production-ready code
```

### Slash Commands

| Command       | Purpose                                       |
| ------------- | --------------------------------------------- |
| `/sdk`        | Core SDK patterns (workflows, nodes, runtime) |
| `/db`         | DataFlow patterns (database operations)       |
| `/api`        | Nexus patterns (multi-channel API deployment) |
| `/ai`         | Kaizen patterns (AI agents)                   |
| `/test`       | 3-tier testing strategy                       |
| `/validate`   | Gold standards compliance check               |
| `/design`     | UI/UX design principles                       |
| `/i-audit`    | Design quality audit with AI slop detection   |
| `/i-harden`   | Production hardening checklist                |
| `/learn`      | Log an observation to the learning system     |
| `/evolve`     | Process instincts into new skills/commands    |
| `/checkpoint` | Save current learning state                   |

---

## Repository Structure

```
.claude/
  settings.json          # Hook configuration + experimental features
  agents/                # 29 agent definitions (Markdown + YAML frontmatter)
    frameworks/          # dataflow-specialist, nexus-specialist, kaizen-specialist, mcp-specialist
    frontend/            # flutter-specialist, react-specialist, ai-ux-designer, uiux-designer
    management/          # gh-manager, git-release-specialist, todo-manager
  commands/              # 12 slash commands (knowledge shortcuts)
  guides/claude-code/    # 15 documentation files (self-documenting architecture)
  rules/                 # 8 mandatory behavioral constraint files
  skills/                # 25 domain knowledge directories, 100+ files

scripts/
  hooks/                 # 8 Node.js lifecycle hooks
    lib/env-utils.js     # Shared model-key validation library
  learning/              # 4 learning system scripts (observe, process, evolve, checkpoint)
  ci/                    # 5 CI validation scripts

CLAUDE.md                # Root project instructions (auto-loaded every session)
```

---

## COC vs. Vibe Coding

| Dimension               | Vibe Coding                                      | Cognitive Orchestration                                |
| ----------------------- | ------------------------------------------------ | ------------------------------------------------------ |
| **Knowledge**           | AI training data (6-12 months stale)             | Living skill library, version-controlled with code     |
| **Memory**              | Context window only; forgotten after compression | Anti-amnesia hooks re-inject rules every turn          |
| **Conventions**         | Random selection from training data              | Enforced by rules + hooks with graduated severity      |
| **Quality**             | Degrades over session length                     | Maintained by 8 hooks + mandatory agent reviews        |
| **Security**            | AI's general awareness                           | 13 regex patterns for key detection + mandatory review |
| **Framework knowledge** | Generic, often wrong                             | 25 specialized skill directories                       |
| **Testing**             | May use mocking, may skip tests                  | NO MOCKING enforced at 8 layers; TDD mandated          |
| **Specialization**      | One generalist AI                                | 29 specialist agents with model-tier optimization      |
| **Improvement**         | None; each session starts fresh                  | Observation-instinct-evolution pipeline                |
| **Accountability**      | None                                             | Mandatory review gates before commit                   |

---

## Relationship to CARE/EATP

COC applies the same trust architecture from the [Kailash SDK's CARE/EATP framework](https://github.com/Integrum-Global/kailash_sdk) to software engineering:

| CARE/EATP Concept                                  | COC Equivalent                                                |
| -------------------------------------------------- | ------------------------------------------------------------- |
| Trust Plane (humans define boundaries)             | Rules + CLAUDE.md (humans define conventions)                 |
| Execution Plane (AI operates at machine speed)     | Agents + Skills (AI generates code with specialist knowledge) |
| Genesis Record (initial trust anchor)              | `session-start.js` (validates env state)                      |
| Trust Lineage Chain (traceability to humans)       | Mandatory review gates before commit                          |
| Audit Anchors (proof of compliance)                | Hook enforcement (deterministic, exit code 2)                 |
| Operating Envelope (boundaries AI must not exceed) | 8 rule files + 8 hook scripts                                 |

COC is the "human-on-the-loop" model applied to codegen: humans define the operating envelope, AI executes within those boundaries at machine speed.

---

## Built For Kailash, Designed For Everyone

This implementation is specialized for [Kailash SDK](https://github.com/Integrum-Global/kailash_sdk) development with its four frameworks:

- **[Core SDK](https://github.com/Integrum-Global/kailash_sdk)** -- 140+ node workflow engine with cryptographic trust
- **[DataFlow](https://github.com/Integrum-Global/kailash-dataflow)** -- Zero-config database with 11 auto-generated nodes per model
- **[Nexus](https://github.com/Integrum-Global/kailash-nexus)** -- Multi-channel deployment (API + CLI + MCP)
- **[Kaizen](https://github.com/Integrum-Global/kailash-kaizen)** -- AI agent framework with CARE/EATP trust

However, the COC architecture -- five layers of intent, context, guardrails, instructions, and learning -- is framework-agnostic. Fork this repository, replace the Kailash-specific skills and agents with your own framework knowledge, and you have a COC setup for any technology stack.

---

## The Self-Sustaining Goal

The end-state of a COC setup is self-sustainability: agents and skills complete enough that a fresh Claude Code session can extend, maintain, and debug the project without instruction templates or human hand-holding.

**The test**: Start a fresh session. Ask it to implement a new feature using only `.claude/agents/` and `.claude/skills/`. If it succeeds -- following all conventions, using the right frameworks, passing all quality gates -- the system is self-sustaining.

> "The problem with vibe coding is not the AI model. It's the absence of institutional knowledge in the coding loop."

---

## License

This project is licensed under the **Apache License, Version 2.0**. See the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <a href=".claude/guides/claude-code/README.md">Full Documentation</a> |
  <a href="https://github.com/Integrum-Global/kailash_sdk">Kailash SDK</a> |
  <a href="https://github.com/Integrum-Global/kailash-vibe-cc-setup">GitHub</a>
</p>
