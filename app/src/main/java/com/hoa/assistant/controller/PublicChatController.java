package com.hoa.assistant.controller;

import com.hoa.assistant.dto.ChatResponse;
import com.hoa.assistant.dto.PublicChatRequest;
import com.hoa.assistant.service.ChatService;
import com.hoa.assistant.service.CommunityService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Public chat controller — no authentication required.
 * Used by the embeddable chat widget on property management websites.
 */
@Slf4j
@RestController
@RequestMapping("/api/public/chat")
@RequiredArgsConstructor
public class PublicChatController {

    private final ChatService chatService;
    private final CommunityService communityService;

    @PostMapping
    public ResponseEntity<ChatResponse> chat(@Valid @RequestBody PublicChatRequest request) {
        log.info("Public chat request: communityId={}, sessionId={}", request.getCommunityId(), request.getSessionId());

        // Boundary validation: community must exist and be active
        communityService.validateActiveCommunity(request.getCommunityId());

        ChatResponse response = chatService.publicChat(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Returns a time-aware greeting for a community.
     * Called when user selects a community in the widget dropdown.
     */
    @GetMapping("/greeting/{communityId}")
    public ResponseEntity<ChatResponse> greeting(@PathVariable Long communityId) {
        communityService.validateActiveCommunity(communityId);

        String greetingText = chatService.buildGreeting(communityId);

        ChatResponse response = ChatResponse.builder()
                .response(greetingText)
                .action("greeting")
                .build();

        return ResponseEntity.ok(response);
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Public chat service is running");
    }
}
