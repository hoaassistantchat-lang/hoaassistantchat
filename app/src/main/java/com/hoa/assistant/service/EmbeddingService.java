package com.hoa.assistant.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hoa.assistant.config.HoaProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import okhttp3.*;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmbeddingService {

    private final OkHttpClient httpClient;
    private final HoaProperties hoaProperties;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public float[] generateEmbedding(String text) {
        try {
            String apiKey = hoaProperties.getApi().getOpenai().getApiKey();
            String apiUrl = hoaProperties.getApi().getOpenai().getApiUrl();
            String model = hoaProperties.getApi().getOpenai().getModel();

            // Validate configuration
            if (apiKey == null || apiKey.isEmpty() || apiKey.contains("${")) {
                log.error("OpenAI API key is not configured. Please set OPENAI_API_KEY environment variable or configure it in application-local.yml");
                throw new RuntimeException("OpenAI API key is not configured");
            }

            Map<String, Object> requestBody = Map.of(
                    "input", text,
                    "model", model
            );

            RequestBody body = RequestBody.create(
                    objectMapper.writeValueAsString(requestBody),
                    MediaType.parse("application/json")
            );

            Request request = new Request.Builder()
                    .url(apiUrl)
                    .addHeader("Authorization", "Bearer " + apiKey)
                    .addHeader("Content-Type", "application/json")
                    .post(body)
                    .build();

            try (Response response = httpClient.newCall(request).execute()) {
                if (!response.isSuccessful()) {
                    log.error("OpenAI API call failed with status code: {}", response.code());
                    String errorBody = response.body() != null ? response.body().string() : "No error details";
                    log.error("OpenAI API error response: {}", errorBody);
                    throw new RuntimeException("Failed to generate embedding: HTTP " + response.code());
                }

                String responseBody = response.body().string();
                JsonNode jsonNode = objectMapper.readTree(responseBody);
                JsonNode embeddingNode = jsonNode.get("data").get(0).get("embedding");

                float[] embedding = new float[embeddingNode.size()];
                for (int i = 0; i < embeddingNode.size(); i++) {
                    embedding[i] = (float) embeddingNode.get(i).asDouble();
                }

                log.debug("Successfully generated embedding with {} dimensions", embedding.length);
                return embedding;
            }
        } catch (IOException e) {
            log.error("Error generating embedding", e);
            throw new RuntimeException("Failed to generate embedding", e);
        }
    }

    public List<float[]> generateBatchEmbeddings(List<String> texts) {
        return texts.stream()
                .map(this::generateEmbedding)
                .toList();
    }
}
