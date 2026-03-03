package com.hoa.assistant.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatResponse {

    @JsonAlias("response_text")   // safety net: accept old field name if Claude still uses it
    private String response;
    private String sessionId;
    private String action;
    @JsonAlias("ticket_data")
    private TicketData ticketData;
    private Long ticketId;
    private Double confidence;
    private List<String> sources;
    
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class TicketData {
        private String type;
        private String description;
        private String location;
        private String priority;
    }
}
