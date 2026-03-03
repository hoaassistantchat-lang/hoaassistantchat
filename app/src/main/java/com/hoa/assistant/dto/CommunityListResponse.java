package com.hoa.assistant.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommunityListResponse {
    private Long id;
    private String name;
    private Boolean isActive;
    private String slug;
}
