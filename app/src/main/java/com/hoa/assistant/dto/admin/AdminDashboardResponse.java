package com.hoa.assistant.dto.admin;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AdminDashboardResponse {

    // Ticket stats
    private long totalTickets;
    private long openTickets;
    private long inProgressTickets;
    private long resolvedTickets;

    // Resident stats
    private long totalResidents;
    private long activeResidents;

    // Document stats
    private long totalDocuments;
    private long processedDocuments;

    // Community info
    private String communityName;
    private String communitySlug;
    private String planTier;
}
