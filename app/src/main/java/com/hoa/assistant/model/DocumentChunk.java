package com.hoa.assistant.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "document_chunks")
public class DocumentChunk {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "document_id", nullable = false)
    private Long documentId;

    @Column(name = "chunk_text", nullable = false, columnDefinition = "TEXT")
    private String chunkText;

    @Column(name = "section_reference")
    private String sectionReference;

    @Column(name = "chunk_index", nullable = false)
    private Integer chunkIndex;

    /**
     * Stored as the pgvector text literal "[x1,x2,...,xN]".
     * Hibernate sends this as a SQL text/varchar parameter; PostgreSQL
     * applies its implicit text→vector cast so the column type is honoured.
     * This matches how the similarity-search query already passes embeddings:
     *   CAST(:queryEmbedding AS vector)
     */
    @Column(columnDefinition = "vector(1536)")
    private String embedding;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "document_id", insertable = false, updatable = false)
    private Document document;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }

    /**
     * Converts a float array to the pgvector text format "[x1,x2,...,xN]"
     * and stores it in the embedding field.
     */
    public void setEmbeddingFromArray(float[] embeddingArray) {
        if (embeddingArray == null) {
            this.embedding = null;
            return;
        }
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < embeddingArray.length; i++) {
            if (i > 0) sb.append(',');
            sb.append(embeddingArray[i]);
        }
        sb.append(']');
        this.embedding = sb.toString();
    }

    /**
     * Parses the stored pgvector text literal back to a float array.
     */
    public float[] getEmbeddingAsArray() {
        if (embedding == null || embedding.isBlank()) return null;
        // strip surrounding [ ]
        String inner = embedding.substring(1, embedding.length() - 1);
        String[] parts = inner.split(",");
        float[] result = new float[parts.length];
        for (int i = 0; i < parts.length; i++) {
            result[i] = Float.parseFloat(parts[i].trim());
        }
        return result;
    }
}
