# Claude Code Component Philosophy Guide

## Purpose

This guide documents the philosophy, first principles, structures, and quality guidance for all Claude Code components. It serves as the authoritative reference for creating, evaluating, and improving Claude Code configurations.

## Contents

| Document | Component | Focus |
|----------|-----------|-------|
| `01-agents.md` | Agents/Subagents | Policy-driven orchestration |
| `02-skills.md` | Skills | Task-critical information delivery |
| `03-hooks.md` | Hooks | Deterministic automation |
| `04-commands.md` | Commands | User interaction shortcuts |
| `05-rules.md` | Rules | Behavioral constraints |
| `06-mcps.md` | MCP Servers | External tool integration |
| `07-custom-docs.md` | Custom Documentation | Knowledge base design |
| `08-quality-templates.md` | Quality Templates | Checklists and templates |

## Core Philosophy

### The Information Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERACTION                          │
│                     (Commands, Questions)                        │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                          AGENTS                                  │
│  • Policy & process focus                                        │
│  • Know WHAT to invoke and WHERE                                 │
│  • Orchestrate skills and fallback to docs                      │
│  • ~100-300 lines of focused instructions                       │
└─────────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                      ▼
┌────────────────────────────┐  ┌────────────────────────────────┐
│         SKILLS             │  │          HOOKS                  │
│  • Critical task info      │  │  • Deterministic automation     │
│  • Common patterns         │  │  • Input validation             │
│  • Quick references        │  │  • Output formatting            │
│  • ~50-250 lines          │  │  • Session management           │
└────────────────────────────┘  └────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FULL DOCUMENTATION                           │
│  (sdk-users, External Docs, API References)                     │
│  • Complete "what it is" and "how to use it"                    │
│  • All edge cases and advanced patterns                         │
│  • Comprehensive examples                                        │
│  • No progress reports or status info                           │
└─────────────────────────────────────────────────────────────────┘
```

### First Principles

1. **Separation of Concerns**: Each component has ONE primary responsibility
2. **Progressive Detail**: Agents → Skills → Full Docs (increasing detail, decreasing frequency)
3. **Context Efficiency**: Minimize token usage while maximizing useful information
4. **Deterministic When Possible**: Prefer hooks over LLM decisions for automatable tasks
5. **Single Source of Truth**: One canonical location for each piece of information

### User's Understanding (VALIDATED)

The user's understanding aligns with official recommendations:

| Component | User Understanding | Official Recommendation | Status |
|-----------|-------------------|------------------------|--------|
| **Agents** | Policy/process focus, invoke skills, fallback to docs | Orchestrators that delegate to skills and tools | ✅ ALIGNED |
| **Skills** | Critical task info, less-used details in sdk-users | Focused task enablement with doc references | ✅ ALIGNED |
| **SDK-users** | Full docs, "what/how", no irrelevant info | Complete reference documentation | ✅ ALIGNED |

## Quality Metrics by Component

| Component | Target Lines | Focus Ratio | Review Frequency |
|-----------|-------------|-------------|------------------|
| Agents | 100-300 | 80% policy / 20% detail | Every PR |
| Skills | 50-250 | 60% patterns / 40% reference | Monthly |
| Hooks | 20-100 | 100% functional | Per change |
| Commands | 10-50 | 100% procedural | Quarterly |
| Rules | 30-100 | 90% constraints / 10% examples | Bi-weekly |
| Documentation | Unlimited | 70% how-to / 30% reference | Weekly |

## Anti-Patterns to Avoid

### 1. Detail Leakage (Agent → Skill Problem)
❌ Agent contains implementation details that belong in skills
✅ Agent references skills for implementation specifics

### 2. Policy Dilution (Skill → Agent Problem)
❌ Skill tries to enforce policies or orchestrate workflows
✅ Skill provides information; agent makes decisions

### 3. Documentation Duplication
❌ Same information in agent, skill, AND full docs
✅ Single source in full docs, references in skill, delegation in agent

### 4. Hook Overreach
❌ Hooks making complex LLM-like decisions
✅ Hooks performing deterministic, automatable tasks

### 5. Context Bloat
❌ Loading all possible information upfront
✅ Loading only what's needed for current task

## Component Interaction Matrix

```
             Agent  Skill  Hook  Command  Rule  MCP  Docs
Agent          -     R      -       -      C     -    F
Skill          -     -      -       -      -     -    R
Hook           -     -      -       -      -     E    -
Command        I     I      -       -      -     -    -
Rule           C     C      C       -      -     -    -
MCP            -     -      E       -      -     -    -
Docs           -     R      -       -      -     -    -

Legend:
R = References (skill points to docs)
C = Constrains (rule limits agent behavior)
I = Invokes (command triggers agent/skill)
E = Executes (hook/MCP runs external code)
F = Falls back to (agent uses docs when skill insufficient)
```

## Quick Reference: When to Use What

| Need | Use | Why |
|------|-----|-----|
| Automate file formatting | Hook | Deterministic, no LLM needed |
| Enforce security checks | Agent + Rule | Policy decision requiring judgment |
| Provide API reference | Skill + Docs | Graduated detail level |
| Block dangerous commands | Hook | Simple pattern matching |
| Choose framework | Agent | Requires context analysis |
| Run external tool | MCP | Tool integration |
| Shortcut for common task | Command | User convenience |

## Navigation

Start with:
1. **New to Claude Code?** → Read `01-agents.md` through `07-custom-docs.md` in order
2. **Improving existing setup?** → Jump to relevant component file
3. **Creating new component?** → Use templates from `08-quality-templates.md`
4. **Evaluating quality?** → Use checklists in `08-quality-templates.md`
