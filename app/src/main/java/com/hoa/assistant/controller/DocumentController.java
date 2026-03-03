package com.hoa.assistant.controller;

import com.hoa.assistant.dto.DocumentUpdateRequest;
import com.hoa.assistant.dto.UrlIngestRequest;
import com.hoa.assistant.model.Document;
import com.hoa.assistant.security.HoaUserDetails;
import com.hoa.assistant.service.DocumentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/documents")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class DocumentController {

    private final DocumentService documentService;

    /**
     * Upload a document. Admins can specify category, description, version.
     */
    @PostMapping("/upload")
    public ResponseEntity<Document> uploadDocument(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "communityId", defaultValue = "1") Long communityId,
            @RequestParam(value = "documentType", defaultValue = "general") String documentType,
            @RequestParam(value = "category", defaultValue = "general") String category,
            @RequestParam(value = "description", required = false) String description,
            @RequestParam(value = "version", required = false) String version,
            @AuthenticationPrincipal HoaUserDetails principal
    ) {
        try {
            log.info("Uploading document: {} for community {}", file.getOriginalFilename(), communityId);
            Long uploadedByUserId = principal != null ? principal.getUserId() : null;
            Document document = documentService.uploadDocument(
                    file, communityId, documentType, category, description, version, uploadedByUserId);

            // Process synchronously (async in a real high-traffic app)
            documentService.processDocument(document.getId());

            return ResponseEntity.ok(document);
        } catch (Exception e) {
            log.error("Error uploading document", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * List active (non-archived) documents for a community, optionally filtered by category.
     */
    @GetMapping("/community/{communityId}")
    public ResponseEntity<List<Document>> getDocuments(
            @PathVariable Long communityId,
            @RequestParam(value = "category", required = false) String category) {
        List<Document> documents = (category != null && !category.isBlank())
                ? documentService.getDocumentsByCategory(communityId, category)
                : documentService.getDocumentsByCommunity(communityId);
        return ResponseEntity.ok(documents);
    }

    /**
     * Get a single document by ID.
     */
    @GetMapping("/{documentId}")
    public ResponseEntity<Document> getDocument(@PathVariable Long documentId) {
        return ResponseEntity.ok(documentService.getDocumentById(documentId));
    }

    /**
     * Update a document's metadata (category, description, version).
     */
    @PatchMapping("/{documentId}")
    public ResponseEntity<Document> updateDocument(
            @PathVariable Long documentId,
            @RequestBody DocumentUpdateRequest request) {
        Document updated = documentService.updateDocumentMetadata(documentId, request);
        return ResponseEntity.ok(updated);
    }

    /**
     * Archive (soft-delete) a document. The file is kept on disk but hidden from listings.
     */
    @DeleteMapping("/{documentId}")
    public ResponseEntity<Void> archiveDocument(@PathVariable Long documentId) {
        documentService.archiveDocument(documentId);
        return ResponseEntity.noContent().build();
    }

    /**
     * Manually trigger (re-)processing of a document for RAG indexing.
     */
    @PostMapping("/{documentId}/process")
    public ResponseEntity<String> processDocument(@PathVariable Long documentId) {
        try {
            documentService.processDocument(documentId);
            return ResponseEntity.ok("Document processed successfully");
        } catch (Exception e) {
            log.error("Error processing document", e);
            return ResponseEntity.internalServerError().body("Failed to process document");
        }
    }

    /**
     * Ingest a web page by URL — fetches HTML, extracts text, chunks + embeds identical to PDF flow.
     */
    @PostMapping("/ingest-url")
    public ResponseEntity<Document> ingestUrl(
            @Valid @RequestBody UrlIngestRequest request,
            @RequestParam(value = "communityId", defaultValue = "1") Long communityId,
            @AuthenticationPrincipal HoaUserDetails principal) {
        try {
            Long userId = principal != null ? principal.getUserId() : null;
            Document document = documentService.ingestUrl(request, communityId, userId);
            return ResponseEntity.ok(document);
        } catch (Exception e) {
            log.error("Error ingesting URL {}", request.getUrl(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Re-fetch and re-index a URL document (wipes old chunks, re-embeds).
     */
    @PostMapping("/{documentId}/refresh")
    public ResponseEntity<Document> refreshDocument(
            @PathVariable Long documentId,
            @AuthenticationPrincipal HoaUserDetails principal) {
        try {
            Document document = documentService.refreshUrlDocument(documentId);
            return ResponseEntity.ok(document);
        } catch (Exception e) {
            log.error("Error refreshing document {}", documentId, e);
            return ResponseEntity.internalServerError().build();
        }
    }
}
