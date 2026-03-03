package com.hoa.assistant.repository;

import com.hoa.assistant.model.Document;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DocumentRepository extends JpaRepository<Document, Long> {
    List<Document> findByCommunityId(Long communityId);
    List<Document> findByCommunityIdAndIsArchivedFalse(Long communityId);
    List<Document> findByCommunityIdAndCategoryAndIsArchivedFalse(Long communityId, String category);
    List<Document> findByCommunityIdAndProcessed(Long communityId, Boolean processed);
    long countByCommunityIdAndIsArchivedFalse(Long communityId);
}
