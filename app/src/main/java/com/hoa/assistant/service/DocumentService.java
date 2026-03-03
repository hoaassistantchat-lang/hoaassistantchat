package com.hoa.assistant.service;

import com.hoa.assistant.config.HoaProperties;
import com.hoa.assistant.dto.DocumentUpdateRequest;
import com.hoa.assistant.dto.UrlIngestRequest;
import com.hoa.assistant.exception.BusinessException;
import com.hoa.assistant.exception.ResourceNotFoundException;
import com.hoa.assistant.model.Document;
import com.hoa.assistant.model.DocumentChunk;
import com.hoa.assistant.provider.storage.DocumentStorageProvider;
import com.hoa.assistant.repository.DocumentChunkRepository;
import com.hoa.assistant.repository.DocumentRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import org.apache.pdfbox.io.RandomAccessReadBufferedFile;
import org.apache.pdfbox.pdfparser.PDFParser;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.jsoup.Jsoup;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class DocumentService {

    private final DocumentRepository documentRepository;
    private final DocumentChunkRepository documentChunkRepository;
    private final EmbeddingService embeddingService;
    private final HoaProperties hoaProperties;
    private final OkHttpClient okHttpClient;
    private final DocumentStorageProvider documentStorageProvider;

    @Transactional
    public Document uploadDocument(MultipartFile file, Long communityId, String documentType) throws IOException {
        return uploadDocument(file, communityId, documentType, null, null, null, null);
    }

    @Transactional
    public Document uploadDocument(MultipartFile file, Long communityId, String documentType,
                                   String category, String description, String version,
                                   Long uploadedByUserId) throws IOException {
        String originalFilename = file.getOriginalFilename();
        String storageRef = documentStorageProvider.store(file, communityId);

        // Create document record
        Document document = new Document();
        document.setCommunityId(communityId);
        document.setFilename(originalFilename);
        document.setDocumentType(documentType);
        document.setFilePath(storageRef);
        document.setProcessed(false);
        document.setSourceType("pdf");
        document.setCategory(category != null ? category : "general");
        document.setDescription(description);
        document.setVersion(version);
        document.setIsArchived(false);
        document.setUploadedByUserId(uploadedByUserId);
        document.setFileSizeBytes(file.getSize());
        document.setMimeType(file.getContentType());

        return documentRepository.save(document);
    }

    /**
     * Process a document page-by-page to avoid loading the entire text into memory at once.
     *
     * Strategy:
     *  - Open the PDF once and read PAGES_PER_BATCH pages at a time.
     *  - Chunk + embed each batch before moving to the next.
     *  - This keeps peak heap usage at ~(PAGES_PER_BATCH × avg-page-size) instead of the full document.
     */
    @Transactional
    public void processDocument(Long documentId) throws IOException {
        Document document = documentRepository.findById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        if (document.getProcessed()) {
            log.info("Document {} already processed", documentId);
            return;
        }
        if (!"pdf".equals(document.getSourceType())) {
            throw new BusinessException("Document " + documentId + " is not a PDF document", "NOT_PDF_DOCUMENT");
        }

        final int PAGES_PER_BATCH = 3;   // small batches = low memory pressure
        int chunkIndex = 0;
        Path localPath = null;

        try {
            localPath = documentStorageProvider.materializeToLocalPath(document.getFilePath());
            try (RandomAccessReadBufferedFile raf = new RandomAccessReadBufferedFile(localPath.toString())) {
                PDFParser parser = new PDFParser(raf);
                try (PDDocument pdDoc = parser.parse()) {
                    int totalPages = pdDoc.getNumberOfPages();
                    log.info("Processing document {} ({} pages) in batches of {}",
                            documentId, totalPages, PAGES_PER_BATCH);

                    PDFTextStripper stripper = new PDFTextStripper();

                    for (int pageStart = 1; pageStart <= totalPages; pageStart += PAGES_PER_BATCH) {
                        int pageEnd = Math.min(pageStart + PAGES_PER_BATCH - 1, totalPages);
                        stripper.setStartPage(pageStart);
                        stripper.setEndPage(pageEnd);

                        String batchText = stripper.getText(pdDoc);
                        if (batchText == null || batchText.isBlank()) continue;

                        chunkIndex = chunkEmbedAndSave(batchText, document.getId(), chunkIndex);
                        batchText = null; // let GC reclaim the raw page text immediately
                    }
                }
            }
        } finally {
            if (localPath != null) {
                documentStorageProvider.cleanupMaterializedPath(localPath);
            }
        }

        document.setProcessed(true);
        documentRepository.save(document);
        log.info("Document {} processed successfully — {} chunks created", documentId, chunkIndex);
    }

    /**
     * Ingest a web page by URL: fetch HTML, extract plain text, chunk + embed, save as a Document.
     */
    @Transactional
    public Document ingestUrl(UrlIngestRequest request, Long communityId, Long uploadedByUserId) throws IOException {
        String url = request.getUrl();
        log.info("Ingesting URL {} for community {}", url, communityId);

        String html = fetchUrl(url);
        String plainText = Jsoup.parse(html).body().text();

        String displayName = (request.getTitle() != null && !request.getTitle().isBlank())
                ? request.getTitle()
                : url;

        Document document = new Document();
        document.setCommunityId(communityId);
        document.setFilename(displayName);
        document.setDocumentType(request.getCategory() != null ? request.getCategory() : "general");
        document.setFilePath("");
        document.setSourceType("url");
        document.setSourceUrl(url);
        document.setProcessed(false);
        document.setCategory(request.getCategory() != null ? request.getCategory() : "general");
        document.setDescription(request.getDescription());
        document.setVersion(request.getVersion());
        document.setIsArchived(false);
        document.setUploadedByUserId(uploadedByUserId);
        document.setFileSizeBytes((long) html.length());
        document.setMimeType("text/html");

        Document savedDoc = documentRepository.save(document);
        chunkEmbedAndSave(plainText, savedDoc.getId(), 0);

        savedDoc.setProcessed(true);
        savedDoc = documentRepository.save(savedDoc);
        log.info("URL document {} ingested — id={}", url, savedDoc.getId());
        return savedDoc;
    }

    /**
     * Re-fetch a URL document: wipe old chunks, re-fetch the page, re-embed.
     */
    @Transactional
    public Document refreshUrlDocument(Long documentId) throws IOException {
        Document document = documentRepository.findById(documentId)
                .orElseThrow(() -> new ResourceNotFoundException("Document not found: " + documentId));

        if (!"url".equals(document.getSourceType())) {
            throw new BusinessException("Document " + documentId + " is not a URL document", "NOT_URL_DOCUMENT");
        }

        log.info("Refreshing URL document {} from {}", documentId, document.getSourceUrl());
        documentChunkRepository.deleteByDocumentId(documentId);
        document.setProcessed(false);
        documentRepository.save(document);

        String html = fetchUrl(document.getSourceUrl());
        String plainText = Jsoup.parse(html).body().text();

        document.setFileSizeBytes((long) html.length());
        chunkEmbedAndSave(plainText, documentId, 0);

        document.setProcessed(true);
        document = documentRepository.save(document);
        log.info("URL document {} refreshed", documentId);
        return document;
    }

    /**
     * Shared helper: chunk text, generate embeddings, and persist DocumentChunks.
     * Returns the next chunkIndex to use (for callers that process in batches).
     */
    private int chunkEmbedAndSave(String text, Long documentId, int startIndex) {
        List<String> chunks = splitIntoChunks(text);
        int chunkIndex = startIndex;
        for (String chunkText : chunks) {
            if (chunkText.isBlank()) continue;
            float[] embedding = embeddingService.generateEmbedding(chunkText);

            DocumentChunk chunk = new DocumentChunk();
            chunk.setDocumentId(documentId);
            chunk.setChunkText(chunkText);
            chunk.setChunkIndex(chunkIndex++);
            chunk.setSectionReference(extractSectionReference(chunkText));
            chunk.setEmbeddingFromArray(embedding);
            documentChunkRepository.save(chunk);
        }
        return chunkIndex;
    }

    private String fetchUrl(String url) throws IOException {
        Request request = new Request.Builder().url(url).build();
        try (Response response = okHttpClient.newCall(request).execute()) {
            if (!response.isSuccessful() || response.body() == null) {
                throw new BusinessException("Failed to fetch URL: " + url + " — HTTP " + response.code());
            }
            return response.body().string();
        }
    }

    /**
     * Split text into overlapping chunks without scanning the entire string backwards.
     *
     * Instead of lastIndexOf('.', end) which is O(n) on large text, we search
     * only a small look-back window near the target boundary.
     */
    private List<String> splitIntoChunks(String text) {
        int chunkSize = hoaProperties.getDocuments().getChunkSize();
        int overlap   = hoaProperties.getDocuments().getChunkOverlap();
        // How far back from the target boundary we search for a sentence break
        int lookBack  = Math.min(150, chunkSize / 4);

        List<String> chunks = new ArrayList<>();
        int start = 0;
        int len   = text.length();

        while (start < len) {
            int end = Math.min(start + chunkSize, len);

            // Search for a sentence boundary only within the look-back window
            if (end < len) {
                int searchFrom = Math.max(start + 1, end - lookBack);
                int lastPeriod = text.lastIndexOf('.', end);
                if (lastPeriod >= searchFrom) {
                    end = lastPeriod + 1;
                }
            }

            String chunk = text.substring(start, end).trim();
            if (!chunk.isEmpty()) {
                chunks.add(chunk);
            }

            // Advance, ensuring we always make forward progress
            int nextStart = end - overlap;
            start = (nextStart > start) ? nextStart : start + 1;
        }

        return chunks;
    }

    private String extractSectionReference(String chunkText) {
        // Use indexOf instead of matches(".*….*") to avoid full-string regex scan
        int sectionStart = chunkText.indexOf("Section");
        if (sectionStart >= 0) {
            // Confirm it looks like "Section N.N"
            String snippet = chunkText.substring(sectionStart,
                    Math.min(sectionStart + 30, chunkText.length()));
            if (snippet.matches("Section\\s+\\d+.*")) {
                int sectionEnd = chunkText.indexOf('\n', sectionStart);
                if (sectionEnd < 0) sectionEnd = Math.min(sectionStart + 50, chunkText.length());
                return chunkText.substring(sectionStart, sectionEnd).trim();
            }
        }
        return null;
    }

    public List<Document> getDocumentsByCommunity(Long communityId) {
        return documentRepository.findByCommunityIdAndIsArchivedFalse(communityId);
    }

    public List<Document> getDocumentsByCategory(Long communityId, String category) {
        return documentRepository.findByCommunityIdAndCategoryAndIsArchivedFalse(communityId, category);
    }

    public Document getDocumentById(Long documentId) {
        return documentRepository.findById(documentId)
                .orElseThrow(() -> new ResourceNotFoundException("Document not found: " + documentId));
    }

    public List<Document> getUnprocessedDocuments(Long communityId) {
        return documentRepository.findByCommunityIdAndProcessed(communityId, false);
    }

    /**
     * Soft-delete: marks document as archived (keeps file on disk and DB record).
     */
    @Transactional
    public void archiveDocument(Long documentId) {
        Document document = getDocumentById(documentId);
        document.setIsArchived(true);
        documentRepository.save(document);
        log.info("Document {} archived", documentId);
    }

    /**
     * Update document metadata (category, description, version).
     */
    @Transactional
    public Document updateDocumentMetadata(Long documentId, DocumentUpdateRequest request) {
        Document document = getDocumentById(documentId);
        if (request.getCategory() != null)    document.setCategory(request.getCategory());
        if (request.getDescription() != null) document.setDescription(request.getDescription());
        if (request.getVersion() != null)     document.setVersion(request.getVersion());
        document = documentRepository.save(document);
        log.info("Document {} metadata updated", documentId);
        return document;
    }
}
