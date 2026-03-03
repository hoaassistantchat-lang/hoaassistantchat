package com.hoa.assistant.dto;

import lombok.Data;

@Data
public class DocumentUpdateRequest {
    private String category;
    private String description;
    private String version;
}
