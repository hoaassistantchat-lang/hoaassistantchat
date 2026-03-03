package com.hoa.assistant.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PublicChatRequest {

    @NotBlank(message = "Message is required")
    private String message;

    private String sessionId;

    @NotNull(message = "Community ID is required")
    private Long communityId;

    /** Optional visitor name — collected when creating tickets (legacy / fallback) */
    private String visitorName;

    /** Optional visitor first name — used instead of visitorName when set */
    private String visitorFirstName;

    /** Optional visitor last name */
    private String visitorLastName;

    /** Optional visitor account / unit number — appended to ticket description */
    private String visitorAccountNumber;

    /** Optional visitor email — collected when creating tickets */
    private String visitorEmail;

    /** Optional visitor phone — collected when creating tickets */
    private String visitorPhone;
}
