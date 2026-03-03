# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Prerequisites: Docker, Java 21, Maven 3.9+
docker-compose up -d                          # Start PostgreSQL (pgvector + init.sql schema)
mvn clean install                             # Full build (both modules)
mvn spring-boot:run -pl app                   # Run the application (port 8080)
mvn spring-boot:run -pl app -Dspring-boot.run.profiles=local  # Run with local API keys

# Testing & Validation
mvn test -pl app                              # Run unit tests
mvn verify -pl app                            # Tests + architecture validation
mvn architecture:validate -pl app             # Architecture validation only

# Run a single test class
mvn test -pl app -Dtest=ChatServiceTest

# Health check
curl http://localhost:8080/api/chat/health
```

## Project Structure

Multi-module Maven project:
- `app/` — Spring Boot 3.2.2 application (Java 21)
- `architecture-validator-plugin/` — Custom Maven plugin that enforces layer dependency rules at build time
- `docs/` — Architecture decisions, golden principles, execution plans
- `init.sql` — Database schema (tables, pgvector extension, indexes); auto-applied by Docker on first run via volume mount

## Architecture (Strictly Enforced)

The app follows a layered architecture with **mechanical enforcement** via the custom Maven plugin. Builds fail on violations.

```
Controller → Service → Repository → Model
              ↓
           Providers (cross-cutting)
```

**Allowed dependencies:**

| Layer | Can depend on |
|-------|--------------|
| Controller | Service, DTO, Config |
| Service | Repository, Model, DTO, Config, Providers |
| Repository | Model, Config |
| Model | nothing |
| DTO | nothing |

**Forbidden:** Controller→Repository, Repository→Service, Model→Service, Service→Controller

All source code lives under `com.hoa.assistant/` in packages: `controller/`, `service/`, `repository/`, `model/`, `dto/`, `config/`, `exception/`.

## Key Conventions

Read `docs/GOLDEN_PRINCIPLES.md` for the full set. The mechanically enforced rules:

1. **Validate at boundaries only** — Use `@Valid` on controller DTOs; services assume valid input, no defensive null checks inside business logic
2. **Exceptions over nulls** — Throw `ResourceNotFoundException` or `BusinessException`; never return null from service methods
3. **`@Transactional` on Service, never Controller** — Controllers handle HTTP only
4. **Immutable DTOs** (`@Builder`, no setters); mutable entities (JPA requires it)
5. **Repositories return domain objects** — Entities or `Optional<Entity>`, never `Map` or `Object[]`
6. **Log actions, not state** — Log what the system does, not what it checks
7. **Let exceptions bubble** — Only catch if you can meaningfully handle; `GlobalExceptionHandler` catches the rest

## Tech Stack

- **LLM**: Anthropic Claude API (claude-sonnet-4) via OkHttp
- **Embeddings**: OpenAI text-embedding-3-small (1536-dim vectors)
- **Database**: PostgreSQL 16 + pgvector (cosine similarity search via IVFFlat index)
- **PDF**: Apache PDFBox 3.0.1 for document ingestion
- **Patterns**: Lombok (`@Data`, `@Builder`, `@Slf4j`, `@RequiredArgsConstructor`), constructor injection, `@ConfigurationProperties` for type-safe config

## API Keys

API keys are **not** stored in `application.yml`. Provide them via either:
- **Local profile**: Add keys to `app/src/main/resources/application-local.yml` (gitignored) and run with `-Dspring-boot.run.profiles=local`
- **Environment variables**: Set `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`

## Adding a New Feature

Follow this order: Model → Repository → DTO → Service → Controller → Tests

## Documentation

- `AGENTS.md` — Entry point for agents, quick rules, progressive disclosure map
- `docs/ARCHITECTURE.md` — Layer rules and responsibilities
- `docs/GOLDEN_PRINCIPLES.md` — 10 mechanical coding rules
- `docs/exec-plans/tech-debt-tracker.md` — Known issues and priorities

Update relevant docs when making architectural decisions.
