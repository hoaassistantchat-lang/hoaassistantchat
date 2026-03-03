package com.hoa.assistant.controller;

import com.hoa.assistant.dto.CreateTicketRequest;
import com.hoa.assistant.model.Ticket;
import com.hoa.assistant.service.TicketService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/tickets")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
public class TicketController {

    private final TicketService ticketService;

    @PostMapping
    public ResponseEntity<Ticket> createTicket(@Valid @RequestBody CreateTicketRequest request) {
        log.info("Creating ticket for community {}: {}", request.getCommunityId(), request.getDescription());
        Ticket ticket = ticketService.createTicket(request);
        return ResponseEntity.ok(ticket);
    }

    @GetMapping("/community/{communityId}")
    public ResponseEntity<List<Ticket>> getTickets(@PathVariable Long communityId) {
        List<Ticket> tickets = ticketService.getTicketsByCommunity(communityId);
        return ResponseEntity.ok(tickets);
    }

    @GetMapping("/community/{communityId}/open")
    public ResponseEntity<List<Ticket>> getOpenTickets(@PathVariable Long communityId) {
        List<Ticket> tickets = ticketService.getOpenTickets(communityId);
        return ResponseEntity.ok(tickets);
    }

    @GetMapping("/{ticketId}")
    public ResponseEntity<Ticket> getTicket(@PathVariable Long ticketId) {
        Ticket ticket = ticketService.getTicketById(ticketId);
        return ResponseEntity.ok(ticket);
    }

    @PatchMapping("/{ticketId}/status")
    public ResponseEntity<Ticket> updateStatus(
            @PathVariable Long ticketId,
            @RequestParam String status
    ) {
        log.info("Updating ticket {} status to {}", ticketId, status);
        Ticket ticket = ticketService.updateTicketStatus(ticketId, status);
        return ResponseEntity.ok(ticket);
    }
}
