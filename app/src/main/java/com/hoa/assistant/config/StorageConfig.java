package com.hoa.assistant.config;

import com.hoa.assistant.provider.storage.DocumentStorageProvider;
import com.hoa.assistant.provider.storage.LocalDocumentStorageProvider;
import com.hoa.assistant.provider.storage.S3DocumentStorageProvider;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.S3Configuration;

import java.net.URI;

@Configuration
public class StorageConfig {

    @Bean
    @ConditionalOnProperty(name = "hoa.documents.provider", havingValue = "local", matchIfMissing = true)
    public DocumentStorageProvider localDocumentStorageProvider(HoaProperties hoaProperties) {
        return new LocalDocumentStorageProvider(hoaProperties);
    }

    @Bean
    @ConditionalOnProperty(name = "hoa.documents.provider", havingValue = "s3")
    public S3Client s3Client(HoaProperties hoaProperties) {
        HoaProperties.DocumentsProperties documents = hoaProperties.getDocuments();
        if (documents.getS3Bucket() == null || documents.getS3Bucket().isBlank()) {
            throw new IllegalStateException("hoa.documents.s3-bucket must be set when hoa.documents.provider=s3");
        }
        S3ClientBuilder builder = S3Client.builder()
                .region(Region.of(documents.getS3Region()))
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(documents.isS3PathStyle())
                        .build());

        if (documents.getS3Endpoint() != null && !documents.getS3Endpoint().isBlank()) {
            builder.endpointOverride(URI.create(documents.getS3Endpoint()));
        }

        return builder.build();
    }

    @Bean
    @ConditionalOnProperty(name = "hoa.documents.provider", havingValue = "s3")
    public DocumentStorageProvider s3DocumentStorageProvider(S3Client s3Client, HoaProperties hoaProperties) {
        return new S3DocumentStorageProvider(s3Client, hoaProperties);
    }
}
