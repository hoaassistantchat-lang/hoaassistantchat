package com.hoa.assistant.service;

import com.hoa.assistant.dto.CreateWidgetClientRequest;
import com.hoa.assistant.dto.WidgetClientResponse;
import com.hoa.assistant.exception.BusinessException;
import com.hoa.assistant.model.WidgetClient;
import com.hoa.assistant.repository.WidgetClientRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class WidgetClientService {

    private final WidgetClientRepository widgetClientRepository;

    @Transactional
    public WidgetClientResponse createClient(CreateWidgetClientRequest request) {
        String apiKey = "wk_" + UUID.randomUUID();
        String domains = String.join(",", request.getAllowedDomains());

        WidgetClient client = WidgetClient.builder()
                .name(request.getName())
                .apiKey(apiKey)
                .allowedDomains(domains)
                .active(true)
                .createdAt(LocalDateTime.now())
                .build();

        WidgetClient saved = widgetClientRepository.save(client);
        log.info("Created widget client '{}' with key {}", saved.getName(), saved.getApiKey());
        return toResponse(saved);
    }

    public List<WidgetClientResponse> listClients() {
        return widgetClientRepository.findAll().stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    @Transactional
    public void deactivateClient(Long id) {
        WidgetClient client = widgetClientRepository.findById(id)
                .orElseThrow(() -> new BusinessException("Widget client not found: " + id));
        client.setActive(false);
        widgetClientRepository.save(client);
        log.info("Deactivated widget client id={}", id);
    }

    /**
     * Validates that the API key exists and the request origin is in the allowlist.
     * Throws BusinessException if validation fails (caller writes 403 response).
     */
    public void validateRequest(String apiKey, String origin) {
        WidgetClient client = widgetClientRepository.findByApiKeyAndActiveTrue(apiKey)
                .orElseThrow(() -> new BusinessException("Invalid or inactive widget API key"));

        String normalizedOrigin = normalizeOrigin(origin);

        boolean allowed = Arrays.stream(client.getAllowedDomains().split(","))
                .map(String::trim)
                .map(this::stripWww)
                .anyMatch(domain -> domain.equalsIgnoreCase(normalizedOrigin));

        if (!allowed) {
            log.warn("Widget key {} rejected for origin '{}'", apiKey, origin);
            throw new BusinessException("Origin not allowed for this widget key");
        }
    }

    /** Strips protocol and normalises to bare domain (no www prefix). */
    private String normalizeOrigin(String origin) {
        String host = origin
                .replaceFirst("^https?://", "")
                .replaceFirst("/.*$", "")   // strip path if any
                .replaceFirst(":\\d+$", ""); // strip port
        return stripWww(host);
    }

    private String stripWww(String domain) {
        return domain.startsWith("www.") ? domain.substring(4) : domain;
    }

    private WidgetClientResponse toResponse(WidgetClient client) {
        List<String> domains = Arrays.stream(client.getAllowedDomains().split(","))
                .map(String::trim)
                .collect(Collectors.toList());
        return WidgetClientResponse.builder()
                .id(client.getId())
                .name(client.getName())
                .apiKey(client.getApiKey())
                .allowedDomains(domains)
                .active(client.isActive())
                .createdAt(client.getCreatedAt())
                .build();
    }
}
