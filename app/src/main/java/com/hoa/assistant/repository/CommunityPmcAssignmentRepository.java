package com.hoa.assistant.repository;

import com.hoa.assistant.model.CommunityPmcAssignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CommunityPmcAssignmentRepository extends JpaRepository<CommunityPmcAssignment, Long> {

    List<CommunityPmcAssignment> findByPmcId(Long pmcId);

    List<CommunityPmcAssignment> findByPmcIdAndIsActiveTrue(Long pmcId);

    Optional<CommunityPmcAssignment> findByCommunityIdAndIsActiveTrue(Long communityId);

    List<CommunityPmcAssignment> findByCommunityId(Long communityId);
}
