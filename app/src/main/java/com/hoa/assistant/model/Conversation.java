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
@Table(name = "conversations")
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "community_id", nullable = false)
    private Long communityId;

    @Column(name = "session_id", nullable = false, unique = true)
    private String sessionId;

    @Column
    private String language = "en";

    @Column(name = "started_at")
    private LocalDateTime startedAt;

    @Column(name = "last_message_at")
    private LocalDateTime lastMessageAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "community_id", insertable = false, updatable = false)
    private Community community;

    @PrePersist
    protected void onCreate() {
        startedAt = LocalDateTime.now();
        lastMessageAt = LocalDateTime.now();
    }
}
