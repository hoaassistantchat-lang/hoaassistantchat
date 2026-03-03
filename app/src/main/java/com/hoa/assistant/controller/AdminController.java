package com.hoa.assistant.controller;

import com.hoa.assistant.dto.CreateCommunityRequest;
import com.hoa.assistant.dto.CreateResidentRequest;
import com.hoa.assistant.dto.CreateWidgetClientRequest;
import com.hoa.assistant.dto.WidgetClientResponse;
import com.hoa.assistant.dto.admin.AdminDashboardResponse;
import com.hoa.assistant.dto.admin.ResidentSummary;
import com.hoa.assistant.dto.admin.UpdateResidentRequest;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.model.Ticket;
import com.hoa.assistant.security.HoaUserDetails;
import com.hoa.assistant.service.AdminService;
import com.hoa.assistant.service.CommunityService;
import com.hoa.assistant.service.TicketService;
import com.hoa.assistant.service.WidgetClientService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * AdminController — all endpoints require ADMIN or SUPER_ADMIN role.
 * The authenticated user's communityId is used automatically to scope all operations.
 */
@Slf4j
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public class AdminController {

    private final AdminService adminService;
    private final TicketService ticketService;
    private final WidgetClientService widgetClientService;
    private final CommunityService communityService;

    // ── Dashboard ─────────────────────────────────────────────

    /**
     * GET /api/admin/dashboard
     * Returns analytics overview for the admin's community.
     */
    @GetMapping("/dashboard")
    public ResponseEntity<AdminDashboardResponse> getDashboard(
            @AuthenticationPrincipal HoaUserDetails principal) {
        AdminDashboardResponse dashboard = adminService.getDashboard(principal.getCommunityId());
        return ResponseEntity.ok(dashboard);
    }

    // ── Tickets ───────────────────────────────────────────────

    /**
     * GET /api/admin/tickets
     * Returns all tickets for the admin's community, optionally filtered by status.
     */
    @GetMapping("/tickets")
    public ResponseEntity<List<Ticket>> getAllTickets(
            @AuthenticationPrincipal HoaUserDetails principal,
            @RequestParam(required = false) String status) {
        List<Ticket> tickets;
        if (status != null && !status.isBlank()) {
            tickets = ticketService.getTicketsByStatus(principal.getCommunityId(), status);
        } else {
            tickets = ticketService.getTicketsByCommunity(principal.getCommunityId());
        }
        return ResponseEntity.ok(tickets);
    }

    /**
     * PATCH /api/admin/tickets/{ticketId}/status
     * Update a ticket's status (open → in_progress → resolved / closed).
     */
    @PatchMapping("/tickets/{ticketId}/status")
    public ResponseEntity<Ticket> updateTicketStatus(
            @PathVariable Long ticketId,
            @RequestParam String status,
            @AuthenticationPrincipal HoaUserDetails principal) {
        Ticket ticket = ticketService.updateTicketStatusByAdmin(ticketId, status, principal.getCommunityId());
        log.info("Admin {} updated ticket {} to status {}", principal.getEmail(), ticketId, status);
        return ResponseEntity.ok(ticket);
    }

    // ── Residents ─────────────────────────────────────────────

    /**
     * GET /api/admin/residents
     * Returns all residents for the admin's community.
     */
    @GetMapping("/residents")
    public ResponseEntity<List<ResidentSummary>> getResidents(
            @AuthenticationPrincipal HoaUserDetails principal) {
        return ResponseEntity.ok(adminService.getResidents(principal.getCommunityId()));
    }

    /**
     * GET /api/admin/residents/{userId}
     * Returns a single resident's profile.
     */
    @GetMapping("/residents/{userId}")
    public ResponseEntity<ResidentSummary> getResident(
            @PathVariable Long userId,
            @AuthenticationPrincipal HoaUserDetails principal) {
        return ResponseEntity.ok(adminService.getResident(principal.getCommunityId(), userId));
    }

    /**
     * PATCH /api/admin/residents/{userId}
     * Update a resident's status or profile fields.
     */
    @PatchMapping("/residents/{userId}")
    public ResponseEntity<ResidentSummary> updateResident(
            @PathVariable Long userId,
            @RequestBody UpdateResidentRequest request,
            @AuthenticationPrincipal HoaUserDetails principal) {
        ResidentSummary updated = adminService.updateResident(
                principal.getCommunityId(), userId, request);
        return ResponseEntity.ok(updated);
    }

    // ── Communities ───────────────────────────────────────────

    /**
     * GET /api/admin/communities
     * List all communities (active + inactive) for management UI.
     */
    @GetMapping("/communities")
    public ResponseEntity<List<com.hoa.assistant.dto.CommunityListResponse>> listCommunities() {
        return ResponseEntity.ok(communityService.getAllCommunitiesWithStatus());
    }

    /**
     * POST /api/admin/communities
     * Create a new HOA community.
     */
    @PostMapping("/communities")
    public ResponseEntity<Community> createCommunity(
            @Valid @RequestBody CreateCommunityRequest request) {
        Community community = communityService.createCommunity(request);
        log.info("Admin created community '{}'", community.getName());
        return ResponseEntity.ok(community);
    }

    /**
     * PATCH /api/admin/communities/{communityId}/status
     * Toggle a community active/inactive.
     */
    @PatchMapping("/communities/{communityId}/status")
    public ResponseEntity<com.hoa.assistant.dto.CommunityListResponse> toggleCommunityStatus(
            @PathVariable Long communityId,
            @RequestParam boolean active) {
        com.hoa.assistant.dto.CommunityListResponse updated =
                communityService.setActive(communityId, active);
        log.info("Community {} set isActive={}", communityId, active);
        return ResponseEntity.ok(updated);
    }

    // ── Resident Management (admin-created) ───────────────────

    /**
     * POST /api/admin/communities/{communityId}/residents
     * Admin creates a resident account (email-verified, no welcome email needed).
     */
    @PostMapping("/communities/{communityId}/residents")
    public ResponseEntity<ResidentSummary> createResident(
            @PathVariable Long communityId,
            @Valid @RequestBody CreateResidentRequest request) {
        ResidentSummary resident = adminService.createResident(communityId, request);
        log.info("Admin created resident '{}' in community {}", request.getEmail(), communityId);
        return ResponseEntity.ok(resident);
    }

    // ── Widget Clients ────────────────────────────────────────

    /**
     * POST /api/admin/widget-clients
     * Create a new domain-locked widget API key.
     */
    @PostMapping("/widget-clients")
    public ResponseEntity<WidgetClientResponse> createWidgetClient(
            @Valid @RequestBody CreateWidgetClientRequest request) {
        WidgetClientResponse created = widgetClientService.createClient(request);
        log.info("Created widget client '{}'", created.getName());
        return ResponseEntity.ok(created);
    }

    /**
     * GET /api/admin/widget-clients
     * List all widget clients.
     */
    @GetMapping("/widget-clients")
    public ResponseEntity<List<WidgetClientResponse>> listWidgetClients() {
        return ResponseEntity.ok(widgetClientService.listClients());
    }

    /**
     * DELETE /api/admin/widget-clients/{id}
     * Deactivate a widget client (soft delete).
     */
    @DeleteMapping("/widget-clients/{id}")
    public ResponseEntity<Void> deactivateWidgetClient(@PathVariable Long id) {
        widgetClientService.deactivateClient(id);
        log.info("Deactivated widget client id={}", id);
        return ResponseEntity.noContent().build();
    }
}
