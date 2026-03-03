package com.hoa.assistant.service;

import com.hoa.assistant.config.HoaProperties;
import com.hoa.assistant.exception.ResourceNotFoundException;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.model.DocumentChunk;
import com.hoa.assistant.model.Faq;
import com.hoa.assistant.repository.CommunityRepository;
import com.hoa.assistant.repository.DocumentChunkRepository;
import com.hoa.assistant.repository.FaqRepository;
import com.pgvector.PGvector;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class RagService {

    private final EmbeddingService embeddingService;
    private final DocumentChunkRepository documentChunkRepository;
    private final CommunityRepository communityRepository;
    private final FaqRepository faqRepository;
    private final HoaProperties hoaProperties;

    public String buildContext(String query, Long communityId) {
        StringBuilder context = new StringBuilder();

        // Add community profile
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new ResourceNotFoundException("Community not found", "COMMUNITY_NOT_FOUND"));
        context.append(buildCommunityProfile(community));

        // Add relevant FAQs
        List<Faq> faqs = faqRepository.findByCommunityId(communityId);
        if (!faqs.isEmpty()) {
            context.append("\n\n[FAQ_ENTRIES]\n");
            faqs.forEach(faq -> {
                context.append("Q: ").append(faq.getQuestion()).append("\n");
                context.append("A: ").append(faq.getAnswer()).append("\n\n");
            });
            context.append("[/FAQ_ENTRIES]\n");
        }

        // Retrieve relevant document chunks using vector search
        float[] queryEmbedding = embeddingService.generateEmbedding(query);
        int topK = hoaProperties.getRag().getTopK();
        
        List<DocumentChunk> relevantChunks = retrieveRelevantChunks(
                communityId, 
                queryEmbedding, 
                topK
        );

        if (!relevantChunks.isEmpty()) {
            context.append("\n\n[DOCUMENT_EXCERPTS]\n");
            relevantChunks.forEach(chunk -> {
                context.append("Document: ").append(chunk.getDocument().getDocumentType()).append("\n");
                if (chunk.getSectionReference() != null) {
                    context.append("Section: ").append(chunk.getSectionReference()).append("\n");
                }
                context.append("Text: ").append(chunk.getChunkText()).append("\n\n");
            });
            context.append("[/DOCUMENT_EXCERPTS]\n");
        }

        return context.toString();
    }

    private String buildCommunityProfile(Community community) {
        return String.format("""
                [COMMUNITY_PROFILE]
                Name: %s
                Time Zone: %s
                Office Hours: %s
                Contact Email: %s
                Contact Phone: %s
                Payment Portal: %s
                Emergency Contact: %s
                [/COMMUNITY_PROFILE]
                """,
                community.getName(),
                community.getTimeZone(),
                community.getOfficeHours() != null ? community.getOfficeHours() : "Not specified",
                community.getContactEmail() != null ? community.getContactEmail() : "Not specified",
                community.getContactPhone() != null ? community.getContactPhone() : "Not specified",
                community.getPaymentPortalUrl() != null ? community.getPaymentPortalUrl() : "Not specified",
                community.getEmergencyContact() != null ? community.getEmergencyContact() : "Not specified"
        );
    }

    private List<DocumentChunk> retrieveRelevantChunks(Long communityId, float[] queryEmbedding, int topK) {
        // Convert embedding to pgvector format
        String embeddingString = new PGvector(queryEmbedding).toString();
        
        return documentChunkRepository.findSimilarChunks(communityId, embeddingString, topK);
    }

    public double calculateConfidence(List<DocumentChunk> chunks) {
        // Simple confidence calculation based on number of relevant chunks found
        // This can be enhanced with similarity scores
        if (chunks.isEmpty()) {
            return 0.0;
        }
        
        // For now, return a fixed confidence if chunks are found
        // In production, you'd calculate this based on similarity scores
        return chunks.size() >= hoaProperties.getRag().getTopK() ? 0.85 : 0.60;
    }
}
