# Golden Principles

**Purpose**: Mechanical rules that define "good code" in this codebase.
**Audience**: Both humans and AI agents.
**Status**: Living document - updated when new patterns emerge.

---

## Core Philosophy

> Code should be correct, maintainable, and legible to future agent runs.
> Stylistic preferences matter less than mechanical correctness.

---

## Principle 1: Prefer Shared Utilities Over Hand-Rolled Helpers

### Rule
If functionality exists in a shared utility, use it. Don't recreate it.

### Why
- Reduces code duplication
- Ensures consistent behavior
- Makes codebase easier to navigate
- Agents can learn patterns from existing utilities

### Examples

❌ **Bad - Hand-rolled retry logic**:
```java
public void uploadDocument() {
    int retries = 3;
    while (retries > 0) {
        try {
            // upload logic
            break;
        } catch (Exception e) {
            retries--;
            Thread.sleep(1000);
        }
    }
}
```

✅ **Good - Use Spring Retry**:
```java
@Retryable(maxAttempts = 3, backoff = @Backoff(delay = 1000))
public void uploadDocument() {
    // upload logic
}
```

### Enforcement
- **Manual**: Code review
- **Automated**: Custom lint rule (future)

---

## Principle 2: Validate at Boundaries, Don't Probe Data

### Rule
Validate input at API boundaries. Never check for null/empty defensively inside business logic.

### Why
- Makes invalid states unrepresentable
- Reduces defensive coding clutter
- Makes bugs obvious (fail fast)
- Clear contract: if method is called, input is valid

### Examples

❌ **Bad - Defensive probing**:
```java
public void processDocument(Document doc) {
    if (doc == null) return;
    if (doc.getId() == null) return;
    if (doc.getFilePath() == null || doc.getFilePath().isEmpty()) return;
    
    // actual logic
}
```

✅ **Good - Validate at boundary**:
```java
// Controller (boundary)
@PostMapping
public ResponseEntity<?> upload(@Valid @RequestBody DocumentRequest request) {
    // Service assumes valid input
    documentService.processDocument(request.toDocument());
    return ResponseEntity.ok().build();
}

// DTO with validation
public class DocumentRequest {
    @NotNull(message = "Document ID required")
    private Long id;
    
    @NotBlank(message = "File path required")
    private String filePath;
}

// Service - no defensive checks needed
public void processDocument(Document doc) {
    // doc is guaranteed to be valid
    String text = extractText(doc.getFilePath());
    // ...
}
```

### Enforcement
- **Manual**: Code review
- **Automated**: SonarQube rule against null checks in Service layer

---

## Principle 3: Use Exceptions for Exceptional Cases

### Rule
Use exceptions for error conditions. Don't return null or Optional for business errors.

### Why
- Forces caller to handle errors
- Makes error paths explicit
- Can't accidentally ignore errors
- Better stack traces for debugging

### Examples

❌ **Bad - Returning null**:
```java
public Document findDocument(Long id) {
    Document doc = repository.findById(id).orElse(null);
    if (doc == null) {
        log.error("Document not found: {}", id);
        return null;
    }
    return doc;
}

// Caller must remember to check
Document doc = service.findDocument(id);
if (doc != null) {  // Easy to forget!
    // ...
}
```

✅ **Good - Throw exception**:
```java
public Document findDocument(Long id) {
    return repository.findById(id)
        .orElseThrow(() -> new ResourceNotFoundException(
            "Document not found: " + id
        ));
}

// Caller doesn't need null check
Document doc = service.findDocument(id);  // Will throw if not found
// Use doc safely here
```

### Enforcement
- **Manual**: Code review
- **Automated**: SpotBugs rule against returning null from Service methods

---

## Principle 4: Transactions at Service Layer, Not Controller

### Rule
Mark @Transactional on Service methods, never on Controllers.

### Why
- Controllers handle HTTP, not business logic
- Service layer owns transaction boundaries
- Easier to test services in isolation
- Clear separation of concerns

### Examples

❌ **Bad - Transaction in Controller**:
```java
@RestController
public class DocumentController {
    @PostMapping
    @Transactional  // ❌ Wrong layer
    public ResponseEntity<?> upload(@RequestBody DocumentRequest req) {
        Document doc = documentService.save(req);
        documentService.processChunks(doc.getId());
        return ResponseEntity.ok(doc);
    }
}
```

✅ **Good - Transaction in Service**:
```java
@Service
public class DocumentService {
    @Transactional  // ✅ Correct layer
    public Document uploadAndProcess(DocumentRequest req) {
        Document doc = save(req);
        processChunks(doc.getId());
        return doc;
    }
}

@RestController
public class DocumentController {
    @PostMapping
    public ResponseEntity<?> upload(@RequestBody DocumentRequest req) {
        Document doc = documentService.uploadAndProcess(req);
        return ResponseEntity.ok(doc);
    }
}
```

### Enforcement
- **Manual**: Code review
- **Automated**: ArchUnit test (see `src/test/java/architecture/LayerTests.java`)

---

## Principle 5: Immutable DTOs, Mutable Entities

### Rule
- DTOs should be immutable (use @Builder, no setters)
- Entities can be mutable (JPA requires it)

### Why
- DTOs represent snapshots - shouldn't change
- Prevents accidental mutations in request/response
- Makes code easier to reason about
- Entities need mutability for JPA lifecycle

### Examples

✅ **Good - Immutable DTO**:
```java
@Data
@Builder
public class ChatResponse {
    private final String response;
    private final String sessionId;
    private final List<String> sources;
    
    // No setters - use builder
}
```

✅ **Good - Mutable Entity** (required by JPA):
```java
@Entity
@Data
public class Message {
    @Id
    @GeneratedValue
    private Long id;
    
    private String content;  // Can be updated via setter
    private LocalDateTime createdAt;
}
```

### Enforcement
- **Manual**: Code review
- **Automated**: Custom lint rule (future)

---

## Principle 6: Repository Methods Return Domain Objects

### Rule
Repositories return entities or `Optional<Entity>`. Never return Map, List<Object[]>, or raw query results.

### Why
- Type safety
- Clear contracts
- Can't access invalid fields
- IDE autocomplete works properly

### Examples

❌ **Bad - Returning Map**:
```java
@Query("SELECT d.id as id, d.filename as name FROM Document d")
List<Map<String, Object>> findDocumentSummaries();

// Caller has to cast and hope
Map<String, Object> result = repo.findDocumentSummaries().get(0);
String filename = (String) result.get("name");  // Runtime error prone
```

✅ **Good - Return projection interface**:
```java
interface DocumentSummary {
    Long getId();
    String getFilename();
}

@Query("SELECT d.id as id, d.filename as filename FROM Document d")
List<DocumentSummary> findDocumentSummaries();

// Type-safe access
DocumentSummary summary = repo.findDocumentSummaries().get(0);
String filename = summary.getFilename();  // Compile-time checked
```

### Enforcement
- **Manual**: Code review
- **Automated**: SonarQube rule

---

## Principle 7: Log Actions, Not State

### Rule
Log what the system is doing, not what it's checking.

### Why
- Reduces log noise
- Makes debugging easier
- Focuses on important events
- Avoids logging sensitive data

### Examples

❌ **Bad - Logging checks**:
```java
log.debug("Checking if document exists");
if (docExists) {
    log.debug("Document exists, processing");
    process();
} else {
    log.debug("Document does not exist");
}
```

✅ **Good - Log actions**:
```java
if (docExists) {
    log.info("Processing document: {}", docId);
    process();
} else {
    log.warn("Document not found: {}", docId);
}
```

### Enforcement
- **Manual**: Code review

---

## Principle 8: API Keys in Environment, Not application.yml

### Rule
Never commit API keys. Use environment variables with defaults for local dev.

### Why
- Security
- Different keys per environment
- Can rotate without code changes

### Examples

❌ **Bad - Hardcoded**:
```yaml
hoa:
  api:
    anthropic:
      api-key: sk-ant-abc123...  # ❌ Never do this
```

✅ **Good - Environment variable**:
```yaml
hoa:
  api:
    anthropic:
      api-key: ${ANTHROPIC_API_KEY:your-api-key-here}
```

```bash
# .env file (not committed)
ANTHROPIC_API_KEY=sk-ant-abc123...
```

### Enforcement
- **Manual**: `.gitignore` blocks `.env`
- **Automated**: Pre-commit hook scans for API key patterns

---

## Principle 9: Tests Describe Behavior, Not Implementation

### Rule
Test names should read like specifications. Test what, not how.

### Why
- Tests become documentation
- Can refactor without changing tests
- Clear intent

### Examples

❌ **Bad - Implementation-focused**:
```java
@Test
void testChatServiceCallsClaudeServiceAndSavesMessage() {
    // ...
}
```

✅ **Good - Behavior-focused**:
```java
@Test
void whenUserAsksQuestion_thenReturnsAnswerWithSources() {
    // Given
    ChatRequest request = ChatRequest.builder()
        .message("What are pool hours?")
        .communityId(1L)
        .build();
    
    // When
    ChatResponse response = chatService.chat(request);
    
    // Then
    assertThat(response.getResponse()).contains("pool");
    assertThat(response.getSources()).isNotEmpty();
}
```

### Enforcement
- **Manual**: Code review

---

## Principle 10: Don't Catch Exceptions You Can't Handle

### Rule
Only catch exceptions if you can do something meaningful. Otherwise, let them bubble up.

### Why
- Swallowing exceptions hides bugs
- Framework handles exceptions better
- Clear error propagation

### Examples

❌ **Bad - Catching and logging**:
```java
try {
    Document doc = processDocument(file);
} catch (Exception e) {
    log.error("Error processing", e);
    // Then what? Exception is lost!
}
```

✅ **Good - Let it bubble**:
```java
// Service
public Document processDocument(File file) throws DocumentProcessingException {
    // Let exceptions propagate
    return parser.parse(file);
}

// Controller
@PostMapping
public ResponseEntity<?> upload(@RequestParam MultipartFile file) {
    try {
        Document doc = documentService.processDocument(file);
        return ResponseEntity.ok(doc);
    } catch (DocumentProcessingException e) {
        return ResponseEntity.badRequest()
            .body("Failed to process: " + e.getMessage());
    }
}
```

### Enforcement
- **Manual**: Code review
- **Automated**: SpotBugs rule against empty catch blocks

---

## How to Use This Document

### For Humans
- Read before starting new features
- Reference during code review
- Update when new patterns emerge

### For Agents
- Check before generating code
- Use as linter error message reference
- Refer to when refactoring

### When to Update
- A pattern emerges 3+ times across the codebase
- Code review reveals repeated issue
- Post-mortem identifies preventable bug

---

## Enforcement Strategy

| Principle | Manual Review | Automated | Priority |
|-----------|---------------|-----------|----------|
| Shared Utilities | ✅ | 🔜 Lint rule | High |
| Boundary Validation | ✅ | 🔜 SonarQube | High |
| Exception Handling | ✅ | ✅ SpotBugs | High |
| Transaction Layer | ✅ | ✅ ArchUnit | High |
| Immutable DTOs | ✅ | 🔜 Lint rule | Medium |
| Repository Types | ✅ | ✅ SonarQube | Medium |
| Logging Style | ✅ | ❌ | Low |
| API Key Security | ✅ | ✅ Pre-commit | Critical |
| Test Naming | ✅ | ❌ | Low |
| Exception Bubbling | ✅ | ✅ SpotBugs | Medium |

---

## Adding New Principles

When adding a new principle:

1. Observe pattern 3+ times in codebase
2. Document: Rule + Why + Examples + Enforcement
3. Update this file
4. Announce in team chat
5. Add to code review checklist
6. Implement automated enforcement if possible

---

**Remember**: These principles exist to make the codebase predictable.
Predictable code is maintainable code. Maintainable code enables velocity.
