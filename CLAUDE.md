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

## AI Assistant Guidelines

1. **Read before writing** — Always read existing files before modifying them.
2. **Keep it simple** — Don't over-engineer. Only build what's needed now.
3. **Update this file** — When adding new tooling, frameworks, scripts, or conventions, update this CLAUDE.md to reflect the current state.
4. **Don't guess** — If requirements are unclear, ask the user for clarification.
5. **Security first** — Never commit secrets, API keys, or credentials. Use environment variables for sensitive configuration.
6. **Test your changes** — Once a test framework is in place, run tests before committing.
