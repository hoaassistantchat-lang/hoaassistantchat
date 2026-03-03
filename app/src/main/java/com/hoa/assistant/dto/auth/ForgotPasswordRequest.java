package com.hoa.assistant.dto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ForgotPasswordRequest {

    @NotBlank
    @Email
    private String email;

    /** Community slug for tenant scoping */
    @NotBlank
    private String communitySlug;
}
