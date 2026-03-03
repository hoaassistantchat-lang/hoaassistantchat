package com.hoa.assistant.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Builder;
import lombok.Value;

@Value
@Builder
public class UrlIngestRequest {

    @NotBlank
    String url;

    /** Display name used as the document filename in the table. */
    String title;

    @Builder.Default
    String category = "general";

    String description;

    String version;
}
