package com.hoa.assistant.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hoa.assistant.service.WidgetClientService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Map;

@Slf4j
@Component
@RequiredArgsConstructor
public class WidgetAuthFilter extends OncePerRequestFilter {

    private final WidgetClientService widgetClientService;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        // Only guard /api/public/** endpoints
        if (!request.getRequestURI().startsWith("/api/public/")) {
            filterChain.doFilter(request, response);
            return;
        }

        // Skip OPTIONS preflight — let CORS handle it
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        String origin = request.getHeader("Origin");

        // No Origin header → same-origin request from the server's own pages → allow through.
        if (origin == null || origin.isBlank()) {
            filterChain.doFilter(request, response);
            return;
        }

        // Origin header present but matches the server itself → HOA's own landing page / admin UI.
        // Modern browsers send Origin on same-origin POST requests; these don't need a widget key.
        if (origin.equalsIgnoreCase(buildServerOrigin(request))) {
            filterChain.doFilter(request, response);
            return;
        }

        String apiKey = request.getHeader("X-Widget-Key");
        if (apiKey == null || apiKey.isBlank()) {
            sendForbidden(response, "Missing X-Widget-Key header");
            return;
        }

        try {
            widgetClientService.validateRequest(apiKey, origin);
        } catch (Exception e) {
            log.warn("Widget auth rejected for origin '{}': {}", origin, e.getMessage());
            sendForbidden(response, e.getMessage());
            return;
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Reconstructs the server's own origin (scheme + host + optional non-default port)
     * to distinguish same-origin browser requests from cross-origin widget embeds.
     */
    private String buildServerOrigin(HttpServletRequest request) {
        String scheme = request.getScheme();
        String host   = request.getServerName();
        int    port   = request.getServerPort();
        boolean defaultPort = ("http".equals(scheme) && port == 80)
                           || ("https".equals(scheme) && port == 443);
        return defaultPort ? scheme + "://" + host : scheme + "://" + host + ":" + port;
    }

    private void sendForbidden(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        Map<String, Object> body = Map.of(
                "timestamp", LocalDateTime.now().toString(),
                "status", 403,
                "error", "Forbidden",
                "message", message
        );
        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
