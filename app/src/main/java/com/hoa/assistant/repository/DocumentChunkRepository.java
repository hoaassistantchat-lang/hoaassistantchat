package com.hoa.assistant.repository;

import com.hoa.assistant.model.DocumentChunk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DocumentChunkRepository extends JpaRepository<DocumentChunk, Long> {
    
    List<DocumentChunk> findByDocumentId(Long documentId);

    void deleteByDocumentId(Long documentId);
    
    @Query(value = """
        SELECT dc.* 
        FROM document_chunks dc
        JOIN documents d ON dc.document_id = d.id
        WHERE d.community_id = :communityId
        ORDER BY dc.embedding <=> CAST(:queryEmbedding AS vector)
        LIMIT :topK
        """, nativeQuery = true)
    List<DocumentChunk> findSimilarChunks(
        @Param("communityId") Long communityId,
        @Param("queryEmbedding") String queryEmbedding,
        @Param("topK") int topK
    );
}
