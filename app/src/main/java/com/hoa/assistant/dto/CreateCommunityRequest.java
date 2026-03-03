package com.hoa.assistant.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateCommunityRequest {

    @NotBlank
    private String name;

    /** URL-friendly slug, e.g. "sunset-hills". Auto-generated from name if blank. */
    private String slug;

    private String timeZone;
    private String officeHours;
    private String contactEmail;
    private String contactPhone;
    private String paymentPortalUrl;
    private String emergencyContact;
}
