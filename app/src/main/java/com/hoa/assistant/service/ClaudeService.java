package com.hoa.assistant.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.hoa.assistant.config.HoaProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ClaudeService {

    private final OkHttpClient httpClient;
    private final HoaProperties hoaProperties;
    private final ObjectMapper objectMapper = new ObjectMapper();

    private String systemPrompt;

    public String chat(String userMessage, List<String> conversationHistory, String contextData) {
        try {
            if (systemPrompt == null) {
                loadSystemPrompt();
            }

            String apiKey = hoaProperties.getApi().getAnthropic().getApiKey();
            String apiUrl = hoaProperties.getApi().getAnthropic().getApiUrl();
            String model = hoaProperties.getApi().getAnthropic().getModel();
            int maxTokens = hoaProperties.getApi().getAnthropic().getMaxTokens();
            double temperature = hoaProperties.getApi().getAnthropic().getTemperature();

            // Build messages array
            ArrayNode messages = objectMapper.createArrayNode();

            // Add conversation history
            if (conversationHistory != null) {
                for (int i = 0; i < conversationHistory.size(); i++) {
                    ObjectNode message = objectMapper.createObjectNode();
                    message.put("role", i % 2 == 0 ? "user" : "assistant");
                    message.put("content", conversationHistory.get(i));
                    messages.add(message);
                }
            }

            // Add current user message with context
            String userMessageWithContext = buildUserMessageWithContext(userMessage, contextData);
            ObjectNode currentMessage = objectMapper.createObjectNode();
            currentMessage.put("role", "user");
            currentMessage.put("content", userMessageWithContext);
            messages.add(currentMessage);

            // Build request body
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("model", model);
            requestBody.put("max_tokens", maxTokens);
            requestBody.put("temperature", temperature);
            requestBody.set("messages", messages);
            requestBody.put("system", systemPrompt);

            RequestBody body = RequestBody.create(
                    objectMapper.writeValueAsString(requestBody),
                    MediaType.parse("application/json")
            );

            Request request = new Request.Builder()
                    .url(apiUrl)
                    .addHeader("x-api-key", apiKey)
                    .addHeader("anthropic-version", "2023-06-01")
                    .addHeader("Content-Type", "application/json")
                    .post(body)
                    .build();

            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    log.error("Claude API call failed: {} - {}", response.code(), response.message());
                    throw new RuntimeException("Failed to get response from Claude: " + response.message());
                }

                String responseBody = response.body().string();
                JsonNode jsonNode = objectMapper.readTree(responseBody);
                
                // Extract text from content array
                JsonNode content = jsonNode.get("content");
                if (content != null && content.isArray() && content.size() > 0) {
                    return content.get(0).get("text").asText();
                }
                
                return "I apologize, but I couldn't generate a proper response. Please try again.";
            }
        } catch (IOException e) {
            log.error("Error calling Claude API", e);
            throw new RuntimeException("Failed to get response from Claude", e);
        }
    }

    private void loadSystemPrompt() throws IOException {
        ClassPathResource resource = new ClassPathResource("prompts/system-prompt.txt");
        systemPrompt = new String(resource.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
    }

    private String buildUserMessageWithContext(String userMessage, String contextData) {
        if (contextData == null || contextData.isEmpty()) {
            return userMessage;
        }

        return String.format("""
                [CONTEXT]
                %s
                [/CONTEXT]
                
                [USER MESSAGE]
                %s
                [/USER MESSAGE]
                """, contextData, userMessage);
    }
}
