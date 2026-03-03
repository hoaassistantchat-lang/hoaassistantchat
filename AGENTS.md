# HOA Assistant - Agent Instructions

**Last Updated**: 2026-02-16
**Target Model**: Claude Sonnet 4.5 / GPT-4

---

## Core Principle

**Humans steer. Agents execute.**

This codebase follows strict architectural patterns with mechanical enforcement.
Before making changes, read the relevant documentation linked below.

---

## Progressive Disclosure Map

### 🏗️ Architecture & Design
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) - Layered architecture, dependency rules
- [`docs/DESIGN.md`](docs/DESIGN.md) - Core design decisions and patterns
- [`docs/design-docs/index.md`](docs/design-docs/index.md) - Detailed design documents

### 📋 Product & Planning
- [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) - Product requirements and features
- [`docs/exec-plans/index.md`](docs/exec-plans/index.md) - Execution plans and progress
- [`docs/exec-plans/tech-debt-tracker.md`](docs/exec-plans/tech-debt-tracker.md) - Known issues

### 🔧 Development Guidelines
- [`docs/BACKEND.md`](docs/BACKEND.md) - Spring Boot patterns and conventions
- [`docs/DATABASE.md`](docs/DATABASE.md) - Schema design and migration patterns
- [`docs/API.md`](docs/API.md) - REST API conventions
- [`docs/TESTING.md`](docs/TESTING.md) - Test patterns and requirements

### 🔐 Security & Operations
- [`docs/SECURITY.md`](docs/SECURITY.md) - Security requirements and patterns
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) - Deployment and operations

---

## Quick Rules (Universal)

1. **Never bypass layer boundaries** - See ARCHITECTURE.md
2. **All decisions go in docs/** - No tribal knowledge
3. **Tests must pass** - Run `mvn test` before committing
4. **Follow existing patterns** - Grep before inventing
5. **Document your changes** - Update relevant docs/ files
6. **Bug fixes: Code only** - Apply fixes directly, no extra .md files unless asked. Report changes concisely.

---

## Layer Dependency Rules

```
UI → Runtime → Service → Repository → Config → Types
         ↓
    Providers (cross-cutting)
```

**Enforcement**: Custom linters in `ci/linters/` validate these rules.

---

## When You're Stuck

1. Check `docs/exec-plans/tech-debt-tracker.md` for known issues
2. Search `docs/design-docs/` for related decisions
3. Grep the codebase for similar patterns
4. If truly novel, document decision in `docs/design-docs/`

---

## Common Tasks

### Adding a New Feature
1. Read `docs/PRODUCT_SPEC.md` to understand context
2. Create entry in `docs/exec-plans/active/[feature-name].md`
3. Follow layer pattern: Model → Repository → Service → Controller
4. Add tests in same commit
5. Update `tech-debt-tracker.md` if shortcuts taken

### Fixing a Bug
1. Write failing test first
2. Fix implementation
3. Verify test passes
4. Check if architectural constraint prevented this bug
5. Update linters if pattern should be enforced

### Refactoring
1. Check `docs/GOLDEN_PRINCIPLES.md` for target patterns
2. Make small, incremental changes
3. Keep tests green throughout
4. Document why (not what) in commit message

---

## Optimization Checklist

Before finalizing this file, verify:
- ☑ Under 100 lines (currently ~80)
- ☑ Every instruction universally applicable
- ☑ No code style rules (use linters/formatters)
- ☑ No task-specific instructions (use progressive disclosure)
- ☑ Progressive disclosure table pointing to detailed docs

---

**Remember**: If it's not in this repository, it doesn't exist for agents.
