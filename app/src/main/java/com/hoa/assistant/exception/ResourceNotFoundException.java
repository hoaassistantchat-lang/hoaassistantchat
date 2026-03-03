package com.hoa.assistant.exception;

/**
 * Thrown when a requested resource (document, ticket, community, etc.) is not found
 */
public class ResourceNotFoundException extends BusinessException {
    
    public ResourceNotFoundException(String message) {
        super(message, "RESOURCE_NOT_FOUND");
    }
    
    public ResourceNotFoundException(String message, String errorCode) {
        super(message, errorCode);
    }

    public ResourceNotFoundException(String resourceType, Long id) {
        super(String.format("%s not found with id: %d", resourceType, id), "RESOURCE_NOT_FOUND");
    }
}
