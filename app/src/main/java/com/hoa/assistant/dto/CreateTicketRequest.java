package com.hoa.assistant.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateTicketRequest {
    
    @NotNull(message = "Community ID is required")
    private Long communityId;
    
    @NotBlank(message = "Ticket type is required")
    private String ticketType;
    
    @NotBlank(message = "Description is required")
    private String description;
    
    private String location;
    
    private String priority = "normal";
    
    private String residentInfo;
}
