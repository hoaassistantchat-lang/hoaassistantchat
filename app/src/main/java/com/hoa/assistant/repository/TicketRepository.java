package com.hoa.assistant.repository;

import com.hoa.assistant.model.Ticket;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TicketRepository extends JpaRepository<Ticket, Long> {
    List<Ticket> findByCommunityId(Long communityId);
    List<Ticket> findByCommunityIdAndStatus(Long communityId, String status);
}
