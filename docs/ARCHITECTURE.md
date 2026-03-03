# Architecture

**Last Updated**: 2026-02-16
**Status**: Active

---

## Overview

HOA Assistant follows a **strict layered architecture** with mechanical enforcement.
Each layer has a specific responsibility and dependency rules.

---

## Layer Structure

```
┌─────────────────────────────────────────────────────┐
│                    Controller                        │  ← REST API endpoints
│                    (UI Layer)                        │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                     Service                          │  ← Business logic
│                  (Runtime Layer)                     │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                   Repository                         │  ← Data access
│                    (Repo Layer)                      │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│                     Model                            │  ← JPA entities
│                   (Types Layer)                      │
└─────────────────────────────────────────────────────┘

         Cross-cutting: Config, DTO, Providers
```

---

## Dependency Rules (ENFORCED)

### ✅ Allowed Dependencies

| From Layer   | Can Depend On                          |
|-------------|----------------------------------------|
| Controller  | Service, DTO, Config                   |
| Service     | Repository, Model, DTO, Config, Providers |
| Repository  | Model, Config                          |
| Model       | (nothing - pure data)                  |
| DTO         | (nothing - pure data)                  |
| Config      | (external libraries only)              |

### ❌ Forbidden Dependencies

- Controller → Repository (bypass Service layer)
- Repository → Service (circular dependency)
- Model → Service (business logic in entities)
- Service → Controller (reverse flow)

### Enforcement Mechanism

**Custom Maven Plugin**: `architecture-validator-plugin`

Run manually:
```bash
mvn architecture:validate
```

Auto-runs in:
- `mvn verify` (before tests)
- CI pipeline (blocks PR merge)

**Error Example**:
```
[ERROR] Architecture Violation in ChatController.java:23
        Controller layer cannot import from Repository layer.
        Use Service layer instead. See docs/ARCHITECTURE.md#layer-rules
        
        Violation: import com.hoa.assistant.repository.DocumentRepository;
```

---

## Layer Responsibilities

### Controller Layer (`controller/`)
**Purpose**: HTTP request/response handling

**Responsibilities**:
- Validate request DTOs
- Call appropriate Service methods
- Transform Service results to DTOs
- Handle HTTP status codes
- CORS configuration

**Rules**:
- No business logic
- No direct database access
- Thin layer (< 50 lines per method)

**Example**:
```java
@PostMapping("/chat")
public ResponseEntity<ChatResponse> chat(@Valid @RequestBody ChatRequest request) {
    ChatResponse response = chatService.chat(request);
    return ResponseEntity.ok(response);
}
```

---

### Service Layer (`service/`)
**Purpose**: Business logic orchestration

**Responsibilities**:
- Implement business rules
- Coordinate multiple repositories
- Handle transactions
- Call external APIs
- Validation logic

**Rules**:
- One service per domain entity
- Methods should be transactional where needed
- Handle exceptions and map to domain errors
- No HTTP concerns (status codes, headers)

**Example**:
```java
@Transactional
public ChatResponse chat(ChatRequest request) {
    // 1. Get/create conversation
    // 2. Build RAG context
    // 3. Call Claude API
    // 4. Save messages
    // 5. Return response
}
```

---

### Repository Layer (`repository/`)
**Purpose**: Data access

**Responsibilities**:
- CRUD operations
- Custom queries
- Vector search operations

**Rules**:
- Extend Spring Data JpaRepository
- Custom queries in interface (using @Query)
- No business logic
- Return entities or Optional<Entity>

**Example**:
```java
@Query(value = """
    SELECT dc.* FROM document_chunks dc
    WHERE dc.community_id = :communityId
    ORDER BY dc.embedding <=> CAST(:embedding AS vector)
    LIMIT :topK
    """, nativeQuery = true)
List<DocumentChunk> findSimilarChunks(
    @Param("communityId") Long communityId,
    @Param("embedding") String embedding,
    @Param("topK") int topK
);
```

---

### Model Layer (`model/`)
**Purpose**: Data structures

**Responsibilities**:
- JPA entity definitions
- Field validation annotations
- Lifecycle callbacks (@PrePersist, @PreUpdate)

**Rules**:
- No business logic
- No service/repository dependencies
- Immutable where possible (use @Builder)
- Clear relationship mappings

**Example**:
```java
@Entity
@Table(name = "tickets")
@Data
@Builder
public class Ticket {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String description;
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
```

---

### DTO Layer (`dto/`)
**Purpose**: API contracts

**Responsibilities**:
- Request/Response objects
- Validation annotations
- API documentation

**Rules**:
- No business logic
- Use validation annotations (@NotNull, @Valid)
- Immutable where possible
- Clear naming (Request/Response suffix)

---

### Config Layer (`config/`)
**Purpose**: Application configuration

**Responsibilities**:
- Bean definitions
- Property mapping
- External client setup

**Rules**:
- No business logic
- Use @ConfigurationProperties for type-safe config
- Document configuration options

---

### Providers (Cross-cutting)
**Purpose**: Shared utilities and cross-cutting concerns

**Allowed in all layers**:
- Logging (slf4j)
- Validation
- Exception handling
- Constants

**Examples**:
- Exception classes
- Utility functions
- Constants
- Enums

---

## Package Structure

```
com.hoa.assistant/
├── controller/          ← UI Layer
│   ├── ChatController.java
│   ├── DocumentController.java
│   └── TicketController.java
├── service/             ← Runtime Layer
│   ├── ChatService.java
│   ├── ClaudeService.java
│   ├── DocumentService.java
│   ├── EmbeddingService.java
│   ├── RagService.java
│   └── TicketService.java
├── repository/          ← Repo Layer
│   ├── CommunityRepository.java
│   ├── ConversationRepository.java
│   ├── DocumentChunkRepository.java
│   ├── DocumentRepository.java
│   ├── FaqRepository.java
│   ├── MessageRepository.java
│   └── TicketRepository.java
├── model/               ← Types Layer
│   ├── Community.java
│   ├── Conversation.java
│   ├── Document.java
│   ├── DocumentChunk.java
│   ├── Faq.java
│   ├── Message.java
│   └── Ticket.java
├── dto/                 ← Data Transfer
│   ├── ChatRequest.java
│   ├── ChatResponse.java
│   ├── CreateTicketRequest.java
│   └── DocumentUploadRequest.java
├── config/              ← Configuration
│   ├── HoaProperties.java
│   └── HttpClientConfig.java
└── exception/           ← Cross-cutting
    ├── ResourceNotFoundException.java
    └── BusinessException.java
```

---

## Adding New Features

When adding a new feature, follow this order:

1. **Model** - Define entity if needed
2. **Repository** - Add data access methods
3. **DTO** - Create request/response objects
4. **Service** - Implement business logic
5. **Controller** - Add REST endpoint
6. **Tests** - Test each layer

**Document the decision** in `docs/design-docs/[feature-name].md`

---

## Anti-Patterns to Avoid

❌ **Controller calling Repository directly**
```java
// BAD
@Autowired
private DocumentRepository documentRepository;
```

❌ **Business logic in Controller**
```java
// BAD - this should be in Service
@PostMapping("/process")
public void process() {
    List<Document> docs = service.getUnprocessed();
    for (Document doc : docs) {
        // processing logic here
    }
}
```

❌ **Circular dependencies**
```java
// BAD
public class ServiceA {
    @Autowired private ServiceB serviceB;
}

public class ServiceB {
    @Autowired private ServiceA serviceA;  // CIRCULAR!
}
```

❌ **Business logic in Model**
```java
// BAD
@Entity
public class Ticket {
    public void processTicket() {  // Business logic in entity!
        // ...
    }
}
```

---

## Testing Strategy

Each layer has specific test patterns:

- **Controller**: `@WebMvcTest` for REST endpoints
- **Service**: `@SpringBootTest` with mocked repositories
- **Repository**: `@DataJpaTest` for database operations
- **Integration**: Full stack tests in `src/test/integration/`

See [`docs/TESTING.md`](TESTING.md) for details.

---

## References

- [Spring Boot Best Practices](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Clean Architecture by Robert Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- OpenAI Agent-First Codebase Learnings (Progressive Disclosure pattern)

---

## Questions?

If something is unclear:
1. Check existing code for patterns
2. Ask in PR review
3. Document decision in `docs/design-docs/`
