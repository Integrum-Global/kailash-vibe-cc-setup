# Workspaces Scope

Work only within `workspaces/<project-name>/`. Read `.claude/` freely but never write to it except `.claude/agents/project/` and `.claude/skills/project/` during phase 05.

## Phase Contract

Follow phases in order using slash commands. Each phase has a human gate — do not proceed without approval.

| Phase | Command      | Output                                               | Gate              |
| ----- | ------------ | ---------------------------------------------------- | ----------------- |
| 01    | `/analyze`   | `01-analysis/`, `02-plans/`, `03-user-flows/`        | Human review      |
| 02    | `/todos`     | `todos/active/`                                      | Human approval    |
| 03    | `/implement` | `src/`, `apps/`, `docs/`                             | All tests passing |
| 04    | `/redteam`   | `04-validate/`                                       | Red team sign-off |
| 05    | `/codify`    | `.claude/agents/project/`, `.claude/skills/project/` | Human review      |

Additional: `/ws` (status dashboard), `/wrapup` (save session notes before ending).

## Modification Protocol

To change how a phase works: update the workspace's `instructions/` file first, get human confirmation, then act. Never modify documentation or instructions outside the current workspace.

## Codebase Locations

- Backend: `src/`
- Web frontend: `apps/web/`
- Mobile frontend: `apps/mobile/`
- Authority docs: `docs/00-authority/` (includes project-level `CLAUDE.md`)
- Todos: `todos/active/`, `todos/completed/`
