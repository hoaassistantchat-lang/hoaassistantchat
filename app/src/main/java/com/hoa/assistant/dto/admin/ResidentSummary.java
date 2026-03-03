package com.hoa.assistant.dto.admin;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class ResidentSummary {
    private Long id;
    private String email;
    private String firstName;
    private String lastName;
    private String unitNumber;
    private String phone;
    private Boolean isActive;
    private Boolean isEmailVerified;
    private LocalDateTime createdAt;
    private LocalDateTime lastLoginAt;
    private List<String> roles;
}
