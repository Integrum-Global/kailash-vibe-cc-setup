# Kailash Setup - Instructions/SOP Deep Analysis

## SOP Architecture

The instructions/ directory implements a **complete Standard Operating Procedure** for AI-assisted development. This is a unique feature not found in Everything Claude Code.

## Directory Structure

```
instructions/
├── 00-manual_checklist/
│   └── 00-initial.md
├── 01-analysis/
│   ├── 01-new-project/
│   │   └── 00-initial-specs.md
│   └── 02-trace-existing-project/
│       └── 00-initial-specs.md
├── 02-plans/
│   └── 00-initial-setup.md
├── 03-implement/
│   └── 00-initial-implement.md
├── 04-codegen-instructions/
│   └── 00-create-agent-skills.md
└── 05-validation/
    └── 00-initial-validate.md
```

## Phase 0: Manual Checklist

**File**: `00-manual_checklist/00-initial.md`

**Purpose**: Minimal checklist template for manual tracking

**Content**: Bare-bones checklist structure for tasks that need manual intervention or tracking outside the Claude Code workflow.

## Phase 1: Analysis

### For NEW Projects

**File**: `01-analysis/01-new-project/00-initial-specs.md`

**Key Requirements**:

#### 1. Explicit Objective Definition
- Clear statement of what the project achieves
- Success criteria
- Measurable outcomes

#### 2. User Workflow Scenarios
- End-to-end user journeys
- Edge cases
- Error scenarios

#### 3. Product-Focused Research
- Market analysis
- Competitor research
- User needs assessment

#### 4. AAA Framework Evaluation

| Category | Description | Example |
|----------|-------------|---------|
| Automate | Tasks that can be fully automated | Data processing |
| Augment | Tasks that AI enhances | Decision support |
| Amplify | Tasks that AI scales | Content creation |

#### 5. Network Effects Analysis

| Effect | Description |
|--------|-------------|
| Accessibility | Making features available to more users |
| Engagement | Increasing user interaction |
| Personalization | Tailoring experiences |
| Connection | Linking users/systems |
| Collaboration | Enabling teamwork |

#### 6. Documentation Requirements
Detailed structure for project documentation output.

### For EXISTING Projects

**File**: `01-analysis/02-trace-existing-project/00-initial-specs.md`

**Key Requirements**:

#### 1. Knowledge Base Creation
- Extract patterns from existing code
- Document assumptions
- Create agent/skill references

#### 2. Assumption Validation Rule
```
80% Reusable patterns (standard)
15% Self-service adaptation (configurable)
5% Custom rules (project-specific)
```

#### 3. 100% Trace Requirement
- Complete understanding of current state
- No undocumented areas
- Full dependency mapping

#### 4. Issue/Feedback Analysis
- Extract user stories from issues
- Prioritize based on impact
- Map to technical requirements

#### 5. Project-Specific Agent/Skill Creation
- Create agents for project patterns
- Define skills for common tasks
- Establish soft rules for reusability

## Phase 2: Planning

**File**: `02-plans/00-initial-setup.md`

**Setup Options**:

### Option A: Parallel Worktrees
For large projects with backend/web/app separation:

```
project/
├── worktree-backend/
├── worktree-web/
└── worktree-app/
```

**Branch Strategy**:
- `staging` - Integration testing
- `production` - Release-ready code

**Coordination**:
- Framework specialists collaborate
- Independent progress in each worktree
- Merge coordination points defined

### Option B: Single Repository
For smaller projects or monoliths.

**Todo Creation**:
- Use todo-manager agent
- Break down requirements into tasks
- Assign to appropriate specialists

## Phase 3: Implementation

**File**: `03-implement/00-initial-implement.md`

### Pre-Implementation Instructions

**For CodeGen (AI-assisted coding)**:

1. **Detailed Todo Breakdown**
   - From plans, create granular tasks
   - Each task is independently completable
   - Clear acceptance criteria

2. **Test-First Approach**
   - Tier 1 → Tier 2 → Tier 3 progression
   - NO MOCKING in Tiers 2-3
   - Real infrastructure required

3. **LLM-Based Agents**
   - Use Kaizen agents instead of naive NLP
   - Signature-based programming
   - Multi-agent coordination

4. **Documentation Location**
   - Developer docs: `docs/00-developers/`
   - API docs: Auto-generated
   - User docs: Separate from developer docs

5. **Worktree Synchronization**
   - Regular sync points
   - Dependency resolution
   - Integration testing

### Implementation Flow
```
Plan → Todo Breakdown → Test First (Tier 1) →
Implementation → Test (Tier 2) → Integration →
Test (Tier 3) → Documentation → Review
```

## Phase 4: CodeGen Instructions

**File**: `04-codegen-instructions/00-create-agent-skills.md`

**Purpose**: Create project-specific agents and skills

### Agent/Skill Role Definitions

For each project, define:
- **Role**: What the agent/skill does
- **Scope**: What areas it covers
- **Knowledge Base**: What documentation it needs
- **Integration**: How it connects to other agents/skills

### Knowledge Base Integration

**Distilled Knowledge**:
- Key patterns extracted
- Common mistakes documented
- Best practices summarized

**Full Knowledge Base**:
- Complete sdk-users reference
- Framework documentation
- API references

### Single Entry Point Pattern

Every agent/skill should have:
```
agent-or-skill/
├── SKILL.md          # Single entry point
├── knowledge/        # Supporting documentation
└── examples/         # Usage examples
```

## Phase 5: Validation

**File**: `05-validation/00-initial-validate.md`

### E2E Validation Workflow

#### 1. End-to-End Testing
- Backend testing
- Frontend testing
- Browser testing
- Mobile testing (if applicable)

#### 2. User Workflow-Based Testing
- Test actual user journeys
- Not just API endpoints
- Include edge cases

#### 3. Parity Validation (if required)
- Compare with reference implementation
- Feature completeness check
- Performance comparison

#### 4. Natural Language LLM Evaluation
**NOT simple regex matching**

Use LLM-based evaluation for:
- Response quality
- Contextual accuracy
- Natural language understanding
- Multi-turn conversation coherence

#### 5. Detailed Testing Checklist
- Functional requirements
- Non-functional requirements
- Security requirements
- Performance requirements

## SOP Workflow Integration

### Complete Flow
```
00-manual_checklist
        ↓
01-analysis (new OR existing)
        ↓
02-plans (worktrees OR single repo)
        ↓
03-implement (test-first)
        ↓
04-codegen (project-specific agents/skills)
        ↓
05-validation (E2E with LLM evaluation)
```

### Agent Integration

| Phase | Primary Agents |
|-------|----------------|
| Analysis | deep-analyst, requirements-analyst, sdk-navigator |
| Planning | framework-advisor, todo-manager, gh-manager |
| Implementation | tdd-implementer, pattern-expert, framework-specialist |
| CodeGen | sdk-navigator, gold-standards-validator |
| Validation | testing-specialist, documentation-validator |

## Gap Analysis: Instructions vs Everything Claude Code

| Aspect | Everything CC | Kailash Instructions |
|--------|---------------|---------------------|
| SOP | None | Complete 5-phase workflow |
| Project Types | None | NEW vs EXISTING handling |
| Worktree Support | None | Full parallel worktree coordination |
| Knowledge Base | Static skills | Dynamic project-specific creation |
| Validation | TDD only | LLM-based evaluation |
| Documentation | Manual | Structured output requirements |

## Unique Strengths

1. **Structured Workflow**: Complete phase-by-phase SOP
2. **Project Type Handling**: Different approaches for new vs existing
3. **Worktree Coordination**: Parallel development support
4. **Knowledge Extraction**: 80/15/5 reusability rule
5. **LLM Evaluation**: Natural language validation, not regex
6. **Agent Integration**: Each phase maps to specific agents
