package com.hoa.assistant.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import lombok.Builder;
import lombok.Value;

import java.util.List;

@Value
@Builder
public class CreateWidgetClientRequest {

    @NotBlank
    String name;

    @NotEmpty
    List<String> allowedDomains;
}
