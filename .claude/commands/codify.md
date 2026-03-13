---
name: codify
description: "Load phase 05 (codify) for the current workspace. Create project agents and skills."
---

## What This Phase Does (present to user)

Capture everything we learned while building this project — the decisions, patterns, and domain knowledge — so that future work starts with full context instead of from scratch. Think of it as writing the institutional memory: next time anyone works on this project, the AI already knows how everything works and why.

## Your Role (communicate to user)

Confirm that the captured knowledge accurately represents how you want the project to work going forward. You're reviewing for intent and accuracy — "Does this describe what we built and why?" — not for technical correctness.

## Workspace Resolution

1. If `$ARGUMENTS` specifies a project name, use `workspaces/$ARGUMENTS/`
2. Otherwise, use the most recently modified directory under `workspaces/` (excluding `instructions/`)
3. If no workspace exists, ask the user to create one first
4. Read all files in `workspaces/<project>/briefs/` for user context (this is the user's input surface)

## Phase Check

- Read `workspaces/<project>/04-validate/` to confirm validation passed
- Read `docs/` and `docs/00-authority/` for knowledge base
- Output goes to `.claude/agents/project/` and `.claude/skills/project/`

## Workflow

### 1. Deep knowledge extraction

Using as many subagents as required, peruse `docs/`, especially `docs/00-authority/`.

- Ultrathink and read beyond the docs into the intent of this project/product
- Understand the roles and use of agents, skills, docs:
  - **Agents** — What to do, how to think about this, what can it work with, following procedural directives
  - **Skills** — Distilled knowledge that agents can achieve 100% situational awareness with
  - **`docs/`** — Full knowledge base

### 2. Decision log consolidation

Collect all decisions from the implementation phase and create a consolidated decision log:

```yaml
decisions:
  - decision: "Description of what was decided"
    rationale: "Why this decision was made"
    alternatives_rejected: "What other options were considered"
    date: 2026-03-13
    initiative: project-name
    confidence: high
```

Store in `workspaces/<project>/decisions.yml` for future reference.

### 3. Pattern observation

Identify recurring patterns from this initiative that could improve future work:

- **Process patterns**: What workflow steps were most/least effective?
- **Decision patterns**: Were there recurring decision types (e.g., "always chose simpler over comprehensive")?
- **Quality patterns**: What issues came up repeatedly during review?
- **Agent patterns**: Which agent combinations worked well together?

Document observations for the learning pipeline. If a pattern appears with high confidence (3+ occurrences), propose it as a candidate rule or skill update.

### 4. Create/Update agents

Create agents in `.claude/agents/project/`.

- Research how Claude subagents should be written, best practices, and how they should be used
- Reference `.claude/agents/_subagent-guide.md` for agent format
- Specialized agents whose combined expertise cover 100% of this codebase/project/product
- Use-case agents that can work across skills and guide the main agent in coordinating work best done by specialized agents

### 5. Create/Update skills

Create accompanying skills in `.claude/skills/project/`.

- Research how Claude skills should be written, best practices, and how they should be used
- Reference `.claude/guides/claude-code/06-the-skill-system.md` for skill format
- Do not create any more subdirectories
- Ensure single entry point for skills (`SKILL.md`) that references multiple skills files in the same directory
  - Skills must be as detailed as possible so agents can deliver most of their work just by using them
  - Do not treat skills as the knowledge base
    - Should contain the most critical information and logical links/frameworks between knowledge base content
    - Should REFERENCE instead of repeating the knowledge base in `docs/`

### 6. Red team the agents and skills

Validate that generated agents and skills are correct, complete, and secure.

### 7. Update memory and session notes

If significant knowledge was gained that applies across sessions:

- Update auto-memory with key patterns and decisions
- Ensure the anti-amnesia rules are still accurate
- Update learned-instincts if new patterns were confirmed

### 8. Present captured knowledge

Summarize what was captured and where it lives. Ask:

- "Does this accurately represent what we decided?"
- "Is there anything we learned that I missed capturing?"
- "Should any of this be kept confidential rather than in the knowledge base?"

### 9. What comes next

After codification, guide the user to the appropriate next step:

**Is this work ready for deployment?**

- All tasks complete → Run final tests and prepare for deployment
- More tasks to implement → Run `/implement` again

**Does this work need further iteration?**

- New concerns emerged → Run `/analyze` on the new concern
- Adjacent initiative needed → Create a new brief and start a new cycle

**Is this work complete?**

- Knowledge is captured, initiative is done → The knowledge base is updated for future sessions

## Agent Teams

Deploy these agents as a team for codification:

**Knowledge extraction team:**

- **deep-analyst** — Identify core patterns, architectural decisions, and domain knowledge worth capturing
- **requirements-analyst** — Distill requirements into reusable agent instructions
- **coc-expert** — Ensure agents and skills follow COC five-layer architecture (codification IS Layer 5 evolution)

**Creation team:**

- **documentation-validator** — Validate that skill examples are correct and runnable
- **intermediate-reviewer** — Review agent/skill quality before finalizing

**Validation team (red team the agents and skills):**

- **gold-standards-validator** — Ensure agents follow the subagent guide and skills follow the skill system guide
- **testing-specialist** — Verify any code examples in skills are testable
- **security-reviewer** — Audit generated agents/skills for prompt injection vectors, insecure patterns, or secrets exposure (codified artifacts persist across all future sessions)
