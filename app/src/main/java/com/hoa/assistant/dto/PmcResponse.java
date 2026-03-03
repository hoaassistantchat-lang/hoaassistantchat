package com.hoa.assistant.dto;

import lombok.Builder;
import lombok.Value;

import java.time.LocalDateTime;
import java.util.List;

@Value
@Builder
public class PmcResponse {

    Long id;
    String companyName;
    String address;
    String city;
    String state;
    String zip;
    String website;
    String email;

    String phoneMain;
    String phoneSecondary;
    String phoneMobile;

    String contact1Name;
    String contact1Title;
    String contact1Phone;
    String contact1Email;

    String contact2Name;
    String contact2Title;
    String contact2Phone;
    String contact2Email;

    String contact3Name;
    String contact3Title;
    String contact3Phone;
    String contact3Email;

    Boolean isActive;
    String notes;
    LocalDateTime createdAt;

    /** Communities currently or previously assigned to this PMC. */
    List<AssignedCommunity> communities;

    @Value
    @Builder
    public static class AssignedCommunity {
        Long assignmentId;
        Long communityId;
        String communityName;
        Boolean isActive;
        LocalDateTime assignedAt;
        LocalDateTime unassignedAt;
    }
}
