package com.hoa.assistant.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "documents")
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "community_id", nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private String filename;

    @Column(name = "document_type", nullable = false)
    private String documentType;

    @Column(name = "file_path", nullable = false)
    private String filePath;

    @Column(name = "upload_date")
    private LocalDateTime uploadDate;

    @Column(nullable = false)
    private Boolean processed = false;

    // --- Week 3-4 enhancements ---
    @Column(nullable = false)
    private String category = "general";

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column
    private String version;

    @Column(name = "is_archived", nullable = false)
    private Boolean isArchived = false;

    @Column(name = "uploaded_by_user_id")
    private Long uploadedByUserId;

    @Column(name = "file_size_bytes")
    private Long fileSizeBytes;

    @Column(name = "mime_type")
    private String mimeType;

    @Column(name = "source_type", nullable = false)
    private String sourceType = "pdf";   // "pdf" | "url"

    @Column(name = "source_url", columnDefinition = "TEXT")
    private String sourceUrl;            // null for PDF docs

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "community_id", insertable = false, updatable = false)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
    private Community community;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        uploadDate = LocalDateTime.now();
    }
}
