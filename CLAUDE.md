# CLAUDE.md — Ere_Monitor

This file provides context for AI assistants working on this repository.

## Project Overview

**Ere_Monitor** is a new project repository. It is currently in initial setup — no source code, build configuration, or tests have been added yet. AI assistants should treat this as a greenfield project and follow the conventions below when contributing.

**Repository**: `YoussefEslam52/Ere_Monitor`

## Current State

- The repository has no source code, dependencies, or build tooling configured yet.
- No default branch exists on the remote; the first push will establish one.
- There is no README, CI/CD pipeline, or test infrastructure in place.

## Development Conventions

### Branching

- Feature branches should follow the pattern: `claude/<description>-<id>` or `feature/<description>`
- Keep commits atomic and well-described
- Push with: `git push -u origin <branch-name>`

### Commit Messages

- Use imperative mood: "Add feature" not "Added feature"
- Keep the subject line under 72 characters
- Add a blank line before the body if more detail is needed
- Reference issue numbers where applicable

### Code Style (to be updated once tooling is chosen)

- Follow the linting and formatting rules defined in project configuration files once they are added (e.g., `.eslintrc`, `.prettierrc`, `pyproject.toml`)
- Prefer explicit over implicit
- Keep functions small and focused
- Write self-documenting code; add comments only where logic is non-obvious

### Testing (to be updated once a test framework is chosen)

- Tests should live alongside or mirror the source directory structure
- Run all tests before pushing changes
- New features require corresponding test coverage

## File Structure (template — update as project evolves)

```
Ere_Monitor/
├── CLAUDE.md              # This file — AI assistant guidance
├── README.md              # Project description and setup instructions (to be added)
├── src/                   # Source code (to be added)
├── tests/                 # Test files (to be added)
├── tasks/
│   ├── todo.md            # Current task plan with checkable items
│   └── lessons.md         # Accumulated lessons from corrections
└── ...                    # Build configs, CI, docs, etc.
```

## Common Commands

_No build, test, or lint commands are configured yet. Update this section as tooling is added._

```bash
# Placeholder — fill in once package manager / build tool is chosen
# Install dependencies:   <command>
# Run dev server:         <command>
# Run tests:              <command>
# Run linter:             <command>
# Build for production:   <command>
```

## Environment Setup

_No environment variables or external services are required yet. Update this section as the project grows._

## Key Architectural Decisions

_None recorded yet. Document significant choices here as they are made, including rationale._

## Workflow Orchestration

### 1. Plan Mode Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy

- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop

- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done

- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## AI Assistant Guidelines

1. **Read before writing** — Always read existing files before modifying them.
2. **Keep it simple** — Don't over-engineer. Only build what's needed now.
3. **Update this file** — When adding new tooling, frameworks, scripts, or conventions, update this CLAUDE.md to reflect the current state.
4. **Don't guess** — If requirements are unclear, ask the user for clarification.
5. **Security first** — Never commit secrets, API keys, or credentials. Use environment variables for sensitive configuration.
6. **Test your changes** — Once a test framework is in place, run tests before committing.
