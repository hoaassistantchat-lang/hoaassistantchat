# Technical Debt Tracker

**Last Updated**: 2026-02-16
**Purpose**: Track known issues, shortcuts, and improvement opportunities

---

## How to Use This File

### For Humans
- Add items when taking shortcuts
- Review weekly, prioritize quarterly
- Link to related GitHub issues

### For Agents
- Check before working in related areas
- Update status when fixing items
- Add new items when constraints prevent ideal solution

---

## Current Tech Debt

### High Priority (Blocks scalability or security)

#### TD-001: Missing Input Validation on Document Upload
**Area**: `DocumentController.uploadDocument()`  
**Issue**: File type and size validation happens too late  
**Impact**: Could accept malicious files  
**Effort**: 2 hours  
**Solution**: Add validation in DTO + custom validator  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-002: API Keys in application.yml
**Area**: Configuration  
**Issue**: Default API keys visible in source  
**Impact**: Security risk if deployed with defaults  
**Effort**: 1 hour  
**Solution**: Document environment variable setup, remove defaults  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-003: No Rate Limiting on Chat Endpoint
**Area**: `ChatController.chat()`  
**Issue**: Can be spammed, driving up API costs  
**Impact**: Cost risk  
**Effort**: 4 hours  
**Solution**: Add Spring Rate Limiter or Bucket4j  
**Status**: Open  
**Created**: 2026-02-16  

---

### Medium Priority (Maintenance burden)

#### TD-004: Document Processing is Synchronous
**Area**: `DocumentService.processDocument()`  
**Issue**: Blocks HTTP request during PDF processing  
**Impact**: Poor UX for large files, timeout risk  
**Effort**: 8 hours  
**Solution**: Use Spring @Async + CompletableFuture, add status endpoint  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-005: No Retry Logic on External API Calls
**Area**: `ClaudeService`, `EmbeddingService`  
**Issue**: Transient failures cause immediate error  
**Impact**: Reduced reliability  
**Effort**: 3 hours  
**Solution**: Add Spring Retry with exponential backoff  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-006: Missing Integration Tests
**Area**: All layers  
**Issue**: Only unit test coverage exists  
**Impact**: Can't verify full flow works  
**Effort**: 16 hours  
**Solution**: Add @SpringBootTest integration tests  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-007: Exception Handling is Too Generic
**Area**: Controllers  
**Issue**: All exceptions return 500  
**Impact**: Poor API consumer experience  
**Effort**: 6 hours  
**Solution**: Add @ControllerAdvice with specific exception handlers  
**Status**: Open  
**Created**: 2026-02-16  

---

### Low Priority (Nice to have)

#### TD-008: No API Documentation
**Area**: All controllers  
**Issue**: No Swagger/OpenAPI spec  
**Impact**: Harder for frontend developers  
**Effort**: 4 hours  
**Solution**: Add Springdoc OpenAPI dependency + annotations  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-009: Hardcoded Chunk Size in DocumentService
**Area**: `DocumentService.splitIntoChunks()`  
**Issue**: Chunk size is hardcoded, not easily tunable  
**Impact**: Can't optimize without code change  
**Effort**: 1 hour  
**Solution**: Already in HoaProperties, just not used everywhere  
**Status**: Open  
**Created**: 2026-02-16  

#### TD-010: No Logging Configuration
**Area**: Logging  
**Issue**: All logs go to stdout, no rotation  
**Impact**: Hard to debug in production  
**Effort**: 2 hours  
**Solution**: Add Logback config with file appenders  
**Status**: Open  
**Created**: 2026-02-16  

---

## Completed Tech Debt

#### TD-000: PDFBox API Version Mismatch ✅
**Area**: `DocumentService.extractTextFromPdf()`  
**Issue**: Using PDFBox 2.x API with 3.x library  
**Impact**: Compilation error  
**Solution**: Updated to use RandomAccessReadBufferedFile + PDFParser  
**Status**: Fixed  
**Completed**: 2026-02-16  
**Fixed By**: User (Nares)  

---

## Architectural Improvements

### AI-001: Add Architecture Validation
**What**: Maven plugin to enforce layer dependencies  
**Why**: Prevent architectural violations  
**Effort**: 8 hours  
**Status**: Planned  

### AI-002: Implement Ralph Wiggum Loop for Testing
**What**: Automated feedback loop - run tests, fix, repeat  
**Why**: Reduce manual QA burden  
**Effort**: 16 hours  
**Status**: Planned  

### AI-003: Add Custom Linters for Golden Principles
**What**: CheckStyle/PMD rules for our patterns  
**Why**: Enforce code quality mechanically  
**Effort**: 12 hours  
**Status**: Planned  

---

## How to Add New Items

```markdown
#### TD-XXX: Brief Description
**Area**: Package or class name
**Issue**: What's wrong
**Impact**: Why it matters
**Effort**: Estimated hours
**Solution**: How to fix
**Status**: Open
**Created**: YYYY-MM-DD
```

---

## Prioritization Criteria

### High Priority If:
- Security vulnerability
- Blocks new features
- Causes production incidents
- Impacts cost significantly

### Medium Priority If:
- Maintenance burden
- Affects developer velocity
- Poor UX but not blocking

### Low Priority If:
- Nice-to-have improvement
- Minor inconvenience
- Can work around easily

---

## Review Schedule

- **Daily**: Check before starting new work
- **Weekly**: Add new items discovered during development
- **Monthly**: Reprioritize based on impact
- **Quarterly**: Allocate sprint time to pay down high-priority debt

---

## Metrics

**Total Open**: 10  
**High Priority**: 3  
**Medium Priority**: 4  
**Low Priority**: 3  

**Completed This Quarter**: 1  
**Average Time to Fix**: TBD  

---

## Related Documents

- [ARCHITECTURE.md](ARCHITECTURE.md) - Why these rules exist
- [GOLDEN_PRINCIPLES.md](GOLDEN_PRINCIPLES.md) - Patterns to follow when fixing
- [exec-plans/](exec-plans/) - Larger refactoring efforts
