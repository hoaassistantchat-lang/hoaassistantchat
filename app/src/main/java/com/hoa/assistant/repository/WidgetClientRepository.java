package com.hoa.assistant.repository;

import com.hoa.assistant.model.WidgetClient;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface WidgetClientRepository extends JpaRepository<WidgetClient, Long> {

    Optional<WidgetClient> findByApiKeyAndActiveTrue(String apiKey);
}
