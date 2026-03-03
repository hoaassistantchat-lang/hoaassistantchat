package com.hoa.assistant.dto;

import lombok.Builder;
import lombok.Value;

import java.time.LocalDateTime;
import java.util.List;

@Value
@Builder
public class WidgetClientResponse {

    Long id;
    String name;
    String apiKey;
    List<String> allowedDomains;
    boolean active;
    LocalDateTime createdAt;
}
