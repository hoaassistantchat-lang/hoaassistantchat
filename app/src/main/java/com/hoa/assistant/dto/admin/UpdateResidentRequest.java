package com.hoa.assistant.dto.admin;

import lombok.Data;

@Data
public class UpdateResidentRequest {
    private Boolean isActive;
    private String firstName;
    private String lastName;
    private String unitNumber;
    private String phone;
}
