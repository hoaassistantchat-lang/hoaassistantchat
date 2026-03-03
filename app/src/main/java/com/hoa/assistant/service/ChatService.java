package com.hoa.assistant.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hoa.assistant.dto.ChatRequest;
import com.hoa.assistant.dto.ChatResponse;
import com.hoa.assistant.dto.CreateTicketRequest;
import com.hoa.assistant.dto.PublicChatRequest;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.model.Conversation;
import com.hoa.assistant.model.Message;
import com.hoa.assistant.model.Ticket;
import com.hoa.assistant.repository.CommunityRepository;
import com.hoa.assistant.repository.ConversationRepository;
import com.hoa.assistant.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChatService {

    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final CommunityRepository communityRepository;
    private final ClaudeService claudeService;
    private final RagService ragService;
    private final TicketService ticketService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * Authenticated chat — original flow for logged-in residents.
     */
    @Transactional
    public ChatResponse chat(ChatRequest request) {
        Conversation conversation = getOrCreateConversation(
                request.getSessionId(),
                request.getCommunityId()
        );

        return processChatMessage(
                conversation,
                request.getMessage(),
                request.getCommunityId(),
                null, null, null, null
        );
    }

    /**
     * Public chat — no authentication required.
     * Used by the embeddable chat widget.
     */
    @Transactional
    public ChatResponse publicChat(PublicChatRequest request) {
        log.info("Public chat: communityId={}, message={}", request.getCommunityId(), request.getMessage());

        Conversation conversation = getOrCreateConversation(
                request.getSessionId(),
                request.getCommunityId()
        );

        // Prefer first+last name over legacy visitorName field
        String visitorName = request.getVisitorName();
        if (request.getVisitorFirstName() != null && !request.getVisitorFirstName().isBlank()) {
            String last = request.getVisitorLastName() != null ? request.getVisitorLastName().trim() : "";
            visitorName = (request.getVisitorFirstName().trim() + " " + last).trim();
        }

        return processChatMessage(
                conversation,
                request.getMessage(),
                request.getCommunityId(),
                visitorName,
                request.getVisitorEmail(),
                request.getVisitorPhone(),
                request.getVisitorAccountNumber()
        );
    }

    /**
     * Generates a time-aware greeting for the given community.
     */
    public String buildGreeting(Long communityId) {
        Community community = communityRepository.findById(communityId).orElse(null);
        String timeGreeting = getTimeBasedGreeting(community != null ? community.getTimeZone() : "America/Chicago");
        String communityName = community != null ? community.getName() : "your community";

        return String.format(
                "%s! I see information available for **%s**. How can I help you today?",
                timeGreeting, communityName
        );
    }

    // ==================== Private helpers ====================

    private ChatResponse processChatMessage(
            Conversation conversation,
            String message,
            Long communityId,
            String visitorName,
            String visitorEmail,
            String visitorPhone,
            String visitorAccountNumber
    ) {
        // Save user message
        saveMessage(conversation.getId(), "user", message);

        // Get conversation history
        List<String> history = getConversationHistory(conversation.getId());

        // Build context using RAG
        String context = ragService.buildContext(message, communityId);

        // Get response from Claude
        String claudeResponse = claudeService.chat(message, history, context);

        // Save assistant message
        saveMessage(conversation.getId(), "assistant", claudeResponse);

        // Update conversation timestamp
        conversation.setLastMessageAt(LocalDateTime.now());
        conversationRepository.save(conversation);

        // Try to parse structured response
        ChatResponse response = parseClaudeResponse(claudeResponse);
        response.setSessionId(conversation.getSessionId());

        // If Claude determined a ticket should be created, persist it now
        if ("create_ticket".equals(response.getAction()) && response.getTicketData() != null) {
            handleTicketCreation(response, conversation, visitorName, visitorEmail, visitorPhone, visitorAccountNumber);
        }

        return response;
    }

    private void handleTicketCreation(
            ChatResponse response,
            Conversation conversation,
            String visitorName,
            String visitorEmail,
            String visitorPhone,
            String visitorAccountNumber
    ) {
        // For public chat: if no contact info yet, ask for it instead of creating
        if (visitorName == null || visitorName.isBlank() || visitorEmail == null || visitorEmail.isBlank()) {
            response.setAction("collect_contact");
            response.setResponse(response.getResponse()
                    + "\n\nTo create a ticket for you, please fill in your contact details below.");
            return;
        }

        try {
            ChatResponse.TicketData td = response.getTicketData();
            CreateTicketRequest ticketReq = new CreateTicketRequest();
            ticketReq.setCommunityId(conversation.getCommunityId());
            ticketReq.setTicketType(td.getType() != null ? td.getType() : "question");

            StringBuilder desc = new StringBuilder(td.getDescription())
                    .append("\n\n--- Submitted by ---")
                    .append("\nName: ").append(visitorName);
            if (visitorAccountNumber != null && !visitorAccountNumber.isBlank()) {
                desc.append("\nAccount #: ").append(visitorAccountNumber);
            }
            desc.append("\nEmail: ").append(visitorEmail);
            if (visitorPhone != null && !visitorPhone.isBlank()) {
                desc.append("\nPhone: ").append(visitorPhone);
            }
            ticketReq.setDescription(desc.toString());
            ticketReq.setLocation(td.getLocation());
            ticketReq.setPriority(td.getPriority() != null ? td.getPriority() : "normal");

            Ticket ticket = ticketService.createTicket(ticketReq);
            response.setTicketId(ticket.getId());
            log.info("Ticket created from public chat: ticketId={}, communityId={}, visitor={}",
                    ticket.getId(), conversation.getCommunityId(), visitorEmail);
        } catch (Exception e) {
            log.error("Failed to persist ticket from chat action: {}", e.getMessage(), e);
        }
    }

    private String getTimeBasedGreeting(String timeZone) {
        try {
            ZonedDateTime now = ZonedDateTime.now(ZoneId.of(timeZone));
            int hour = now.getHour();
            if (hour >= 5 && hour < 12) return "Good Morning";
            if (hour >= 12 && hour < 17) return "Good Afternoon";
            return "Good Evening";
        } catch (Exception e) {
            log.debug("Invalid timezone {}, defaulting to generic greeting", timeZone);
            return "Hello";
        }
    }

    private Conversation getOrCreateConversation(String sessionId, Long communityId) {
        if (sessionId != null) {
            return conversationRepository.findBySessionId(sessionId)
                    .orElseGet(() -> createNewConversation(communityId));
        } else {
            return createNewConversation(communityId);
        }
    }

    private Conversation createNewConversation(Long communityId) {
        Conversation conversation = new Conversation();
        conversation.setCommunityId(communityId);
        conversation.setSessionId(UUID.randomUUID().toString());
        conversation.setLanguage("en");
        return conversationRepository.save(conversation);
    }

    private void saveMessage(Long conversationId, String role, String content) {
        Message message = new Message();
        message.setConversationId(conversationId);
        message.setRole(role);
        message.setContent(content);
        messageRepository.save(message);
    }

    private List<String> getConversationHistory(Long conversationId) {
        List<Message> messages = messageRepository.findByConversationIdOrderByCreatedAtAsc(conversationId);

        // Get last 10 messages for context (5 exchanges)
        int startIndex = Math.max(0, messages.size() - 10);

        return messages.subList(startIndex, messages.size()).stream()
                .map(Message::getContent)
                .collect(Collectors.toList());
    }

    private ChatResponse parseClaudeResponse(String claudeResponse) {
        String json = extractJson(claudeResponse);
        if (json != null) {
            try {
                return objectMapper.readValue(json, ChatResponse.class);
            } catch (Exception e) {
                log.debug("JSON parsing failed, falling back to plain text: {}", e.getMessage());
            }
        }

        // Strip any leaked JSON from the display text and return as plain answer
        String cleanText = claudeResponse.replaceAll("(?s)```json.*?```", "").trim();
        return ChatResponse.builder()
                .response(cleanText)
                .action("answer")
                .build();
    }

    /**
     * Extracts the first JSON object from a string.
     * Handles: pure JSON, markdown-fenced JSON (```json...```), and JSON embedded after plain text.
     */
    private String extractJson(String text) {
        if (text == null || text.isBlank()) return null;

        // 1. Strip markdown code fences
        java.util.regex.Matcher fenced = java.util.regex.Pattern
                .compile("```(?:json)?\\s*(\\{.*?})\\s*```", java.util.regex.Pattern.DOTALL)
                .matcher(text);
        if (fenced.find()) return fenced.group(1).trim();

        // 2. Find the first { ... } block in the raw text
        int start = text.indexOf('{');
        if (start == -1) return null;
        int depth = 0;
        for (int i = start; i < text.length(); i++) {
            if (text.charAt(i) == '{') depth++;
            else if (text.charAt(i) == '}') {
                depth--;
                if (depth == 0) return text.substring(start, i + 1).trim();
            }
        }
        return null;
    }
}
