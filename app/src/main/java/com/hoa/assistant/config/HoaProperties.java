package com.hoa.assistant.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Data
@Configuration
@ConfigurationProperties(prefix = "hoa")
public class HoaProperties {

    private ApiProperties api = new ApiProperties();
    private DocumentsProperties documents = new DocumentsProperties();
    private RagProperties rag = new RagProperties();

    @Data
    public static class ApiProperties {
        private AnthropicProperties anthropic = new AnthropicProperties();
        private OpenAiProperties openai = new OpenAiProperties();
    }

    @Data
    public static class AnthropicProperties {
        private String apiKey;
        private String apiUrl;
        private String model;
        private int maxTokens;
        private double temperature;
    }

    @Data
    public static class OpenAiProperties {
        private String apiKey;
        private String apiUrl;
        private String model;
    }

    @Data
    public static class DocumentsProperties {
        private String provider = "local";
        private String storagePath;
        private int chunkSize;
        private int chunkOverlap;
        private String s3Bucket;
        private String s3Region = "us-east-1";
        private String s3Prefix = "documents";
        private String s3Endpoint;
        private boolean s3PathStyle = false;
    }

    @Data
    public static class RagProperties {
        private int topK;
        private double confidenceThreshold;
    }
}
