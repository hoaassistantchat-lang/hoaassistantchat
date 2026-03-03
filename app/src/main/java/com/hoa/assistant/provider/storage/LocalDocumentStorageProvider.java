package com.hoa.assistant.provider.storage;

import com.hoa.assistant.config.HoaProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

@RequiredArgsConstructor
public class LocalDocumentStorageProvider implements DocumentStorageProvider {

    private final HoaProperties hoaProperties;

    @Override
    public String store(MultipartFile file, Long communityId) throws IOException {
        String storagePath = hoaProperties.getDocuments().getStoragePath();
        Path uploadPath = Paths.get(storagePath);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        String originalFilename = file.getOriginalFilename();
        String safeName = sanitizeFilename(originalFilename);
        String filename = UUID.randomUUID() + "_" + safeName;
        Path filePath = uploadPath.resolve(filename);
        Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);
        return filePath.toString();
    }

    @Override
    public Path materializeToLocalPath(String storageRef) {
        return Paths.get(storageRef);
    }

    private String sanitizeFilename(String originalFilename) {
        if (originalFilename == null || originalFilename.isBlank()) {
            return "document.pdf";
        }
        return originalFilename.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
