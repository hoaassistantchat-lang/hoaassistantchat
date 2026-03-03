package com.hoa.assistant.provider.storage;

import com.hoa.assistant.config.HoaProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

@RequiredArgsConstructor
public class S3DocumentStorageProvider implements DocumentStorageProvider {

    private static final String TEMP_PREFIX = "hoa-doc-s3-";

    private final S3Client s3Client;
    private final HoaProperties hoaProperties;

    @Override
    public String store(MultipartFile file, Long communityId) throws IOException {
        String key = buildObjectKey(communityId, file.getOriginalFilename());

        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(hoaProperties.getDocuments().getS3Bucket())
                .key(key)
                .contentType(file.getContentType())
                .build();

        s3Client.putObject(request, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
        return key;
    }

    @Override
    public Path materializeToLocalPath(String storageRef) throws IOException {
        // Migration-friendly fallback: if an absolute path exists, keep using it.
        Path maybeLocal = Paths.get(storageRef);
        if (maybeLocal.isAbsolute() && Files.exists(maybeLocal)) {
            return maybeLocal;
        }

        String key = extractKey(storageRef);
        Path tempFile = Files.createTempFile(TEMP_PREFIX, ".pdf");

        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(hoaProperties.getDocuments().getS3Bucket())
                .key(key)
                .build();

        try (InputStream in = s3Client.getObject(request)) {
            Files.copy(in, tempFile, StandardCopyOption.REPLACE_EXISTING);
        }
        return tempFile;
    }

    @Override
    public void cleanupMaterializedPath(Path path) throws IOException {
        String fileName = path.getFileName() != null ? path.getFileName().toString() : "";
        if (fileName.startsWith(TEMP_PREFIX)) {
            Files.deleteIfExists(path);
        }
    }

    private String buildObjectKey(Long communityId, String originalFilename) {
        String prefix = hoaProperties.getDocuments().getS3Prefix();
        String safeName = sanitizeFilename(originalFilename);
        return String.format("%s/community-%d/%s_%s", prefix, communityId, UUID.randomUUID(), safeName);
    }

    private String extractKey(String storageRef) {
        if (storageRef == null || storageRef.isBlank()) {
            throw new IllegalArgumentException("Document storage reference is blank");
        }

        if (!storageRef.startsWith("s3://")) {
            return storageRef;
        }

        String withoutScheme = storageRef.substring("s3://".length());
        int slash = withoutScheme.indexOf('/');
        if (slash < 0) {
            throw new IllegalArgumentException("Invalid s3 storage reference: " + storageRef);
        }

        return withoutScheme.substring(slash + 1);
    }

    private String sanitizeFilename(String originalFilename) {
        if (originalFilename == null || originalFilename.isBlank()) {
            return "document.pdf";
        }
        return originalFilename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
