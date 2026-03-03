package com.hoa.assistant.provider.storage;

import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Path;

public interface DocumentStorageProvider {

    String store(MultipartFile file, Long communityId) throws IOException;

    Path materializeToLocalPath(String storageRef) throws IOException;

    default void cleanupMaterializedPath(Path path) throws IOException {
        // no-op by default
    }
}
