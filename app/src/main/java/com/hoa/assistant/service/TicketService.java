package com.hoa.assistant.service;

import com.hoa.assistant.dto.CreateTicketRequest;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.model.Ticket;
import com.hoa.assistant.repository.CommunityRepository;
import com.hoa.assistant.repository.TicketRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class TicketService {

    private final TicketRepository ticketRepository;
    private final CommunityRepository communityRepository;
    private final EmailService emailService;

    @Transactional
    public Ticket createTicket(CreateTicketRequest request) {
        Ticket ticket = new Ticket();
        ticket.setCommunityId(request.getCommunityId());
        ticket.setTicketType(request.getTicketType());
        ticket.setDescription(request.getDescription());
        ticket.setLocation(request.getLocation());
        ticket.setPriority(request.getPriority());
        ticket.setStatus("open");
        ticket.setResidentInfo(request.getResidentInfo());

        Ticket savedTicket = ticketRepository.save(ticket);
        log.info("Created ticket {} for community {}", savedTicket.getId(), request.getCommunityId());

        // Send email notification (Week 3-4)
        String communityName = communityRepository.findById(request.getCommunityId())
                .map(Community::getName).orElse("HOA");
        // Extract email from residentInfo if present (format: "Name <email>")
        String residentEmail = extractEmail(request.getResidentInfo());
        emailService.sendTicketCreatedEmail(savedTicket, residentEmail, communityName);

        return savedTicket;
    }

    /** Extract email address from residentInfo string, if it contains one. */
    private String extractEmail(String residentInfo) {
        if (residentInfo == null) return null;
        // Match pattern like "email@domain.com" anywhere in the string
        java.util.regex.Matcher m = java.util.regex.Pattern
                .compile("[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}")
                .matcher(residentInfo);
        return m.find() ? m.group() : null;
    }

    public List<Ticket> getTicketsByCommunity(Long communityId) {
        return ticketRepository.findByCommunityId(communityId);
    }

    public List<Ticket> getOpenTickets(Long communityId) {
        return ticketRepository.findByCommunityIdAndStatus(communityId, "open");
    }

    public List<Ticket> getTicketsByStatus(Long communityId, String status) {
        return ticketRepository.findByCommunityIdAndStatus(communityId, status);
    }

    public Ticket getTicketById(Long ticketId) {
        return ticketRepository.findById(ticketId)
                .orElseThrow(() -> new RuntimeException("Ticket not found"));
    }

    @Transactional
    public Ticket updateTicketStatus(Long ticketId, String status) {
        Ticket ticket = getTicketById(ticketId);
        ticket.setStatus(status);

        if ("resolved".equals(status) || "closed".equals(status)) {
            ticket.setResolvedAt(LocalDateTime.now());
        }

        return ticketRepository.save(ticket);
    }

    /**
     * Admin-scoped status update — verifies ticket belongs to admin's community.
     * Sends an email notification to the resident if possible.
     */
    @Transactional
    public Ticket updateTicketStatusByAdmin(Long ticketId, String status, Long communityId) {
        Ticket ticket = getTicketById(ticketId);
        if (!communityId.equals(ticket.getCommunityId())) {
            throw new RuntimeException("Ticket does not belong to this community");
        }
        ticket.setStatus(status);
        if ("resolved".equals(status) || "closed".equals(status)) {
            ticket.setResolvedAt(LocalDateTime.now());
        }
        Ticket saved = ticketRepository.save(ticket);

        // Send status update email
        String communityName = communityRepository.findById(communityId)
                .map(Community::getName).orElse("HOA");
        String residentEmail = extractEmail(ticket.getResidentInfo());
        emailService.sendTicketUpdatedEmail(saved, residentEmail, communityName);

        return saved;
    }
}
