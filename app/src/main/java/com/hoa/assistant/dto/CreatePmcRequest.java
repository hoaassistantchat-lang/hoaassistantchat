package com.hoa.assistant.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

/**
 * Used for both CREATE (POST) and UPDATE (PATCH) of a Property Management Company.
 * On create, companyName is @NotBlank. On patch, the service ignores null fields.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreatePmcRequest {

    @NotBlank
    private String companyName;

    private String address;
    private String city;
    private String state;
    private String zip;
    private String website;
    private String email;

    // Company-level phone lines
    private String phoneMain;
    private String phoneSecondary;
    private String phoneMobile;

    // Contact 1
    private String contact1Name;
    private String contact1Title;
    private String contact1Phone;
    private String contact1Email;

    // Contact 2
    private String contact2Name;
    private String contact2Title;
    private String contact2Phone;
    private String contact2Email;

    // Contact 3
    private String contact3Name;
    private String contact3Title;
    private String contact3Phone;
    private String contact3Email;

    private String notes;
}
