package com.hoa.assistant.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "property_management_companies")
public class PropertyManagementCompany {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_name", nullable = false)
    private String companyName;

    @Column
    private String address;

    @Column
    private String city;

    @Column
    private String state;

    @Column
    private String zip;

    @Column
    private String website;

    @Column
    private String email;

    // Company-level phone lines
    @Column(name = "phone_main")
    private String phoneMain;

    @Column(name = "phone_secondary")
    private String phoneSecondary;

    @Column(name = "phone_mobile")
    private String phoneMobile;

    // Contact 1 — primary (e.g. Account Manager)
    @Column(name = "contact1_name")
    private String contact1Name;

    @Column(name = "contact1_title")
    private String contact1Title;

    @Column(name = "contact1_phone")
    private String contact1Phone;

    @Column(name = "contact1_email")
    private String contact1Email;

    // Contact 2 — secondary (e.g. Operations)
    @Column(name = "contact2_name")
    private String contact2Name;

    @Column(name = "contact2_title")
    private String contact2Title;

    @Column(name = "contact2_phone")
    private String contact2Phone;

    @Column(name = "contact2_email")
    private String contact2Email;

    // Contact 3 — tertiary (e.g. Emergency / After-hours)
    @Column(name = "contact3_name")
    private String contact3Name;

    @Column(name = "contact3_title")
    private String contact3Title;

    @Column(name = "contact3_phone")
    private String contact3Phone;

    @Column(name = "contact3_email")
    private String contact3Email;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
