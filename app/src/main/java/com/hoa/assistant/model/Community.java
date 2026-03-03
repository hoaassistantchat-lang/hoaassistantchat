package com.hoa.assistant.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Entity
@Table(name = "communities")
public class Community {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    /** Unique URL-friendly identifier for tenant lookup (e.g. "sunset-hills") */
    @Column(unique = true)
    private String slug;

    @Column(name = "plan_tier")
    private String planTier = "basic";

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "max_admins")
    private Integer maxAdmins = 3;

    @Column(name = "max_residents")
    private Integer maxResidents = 500;

    @Column(name = "time_zone", nullable = false)
    private String timeZone = "America/Los_Angeles";

    @Column(name = "office_hours")
    private String officeHours;

    @Column(name = "contact_email")
    private String contactEmail;

    @Column(name = "contact_phone")
    private String contactPhone;

    @Column(name = "payment_portal_url")
    private String paymentPortalUrl;

    @Column(name = "emergency_contact")
    private String emergencyContact;

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
