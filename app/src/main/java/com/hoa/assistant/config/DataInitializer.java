package com.hoa.assistant.config;

import com.hoa.assistant.model.User;
import com.hoa.assistant.repository.CommunityRepository;
import com.hoa.assistant.repository.RoleRepository;
import com.hoa.assistant.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements ApplicationRunner {

    private static final String COMMUNITY_SLUG = "sunset-hills";
    private static final String COMMUNITY_NAME = "Sunset Hills HOA";
    private static final String ADMIN_EMAIL    = "admin@sunsethills.hoa";
    private static final String ADMIN_PASSWORD = "Admin@123";

    private final CommunityRepository communityRepository;
    private final UserRepository      userRepository;
    private final RoleRepository      roleRepository;
    private final PasswordEncoder     passwordEncoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        // Try by slug first; fall back to name for communities seeded before the slug column existed
        var community = communityRepository.findBySlug(COMMUNITY_SLUG)
                .or(() -> communityRepository.findFirstByNameOrderByIdAsc(COMMUNITY_NAME)
                        .map(c -> {
                            // Backfill missing slug
                            c.setSlug(COMMUNITY_SLUG);
                            communityRepository.save(c);
                            log.info("DataInitializer: backfilled slug '{}' for community '{}'", COMMUNITY_SLUG, COMMUNITY_NAME);
                            return c;
                        }))
                .orElse(null);

        // Clean up duplicate communities created by failed migration retries
        var duplicates = communityRepository.findAllByName(COMMUNITY_NAME).stream()
                .filter(c -> !c.getId().equals(community != null ? community.getId() : -1L))
                .toList();
        if (!duplicates.isEmpty()) {
            communityRepository.deleteAll(duplicates);
            log.info("DataInitializer: removed {} duplicate community row(s)", duplicates.size());
        }

        if (community == null) {
            log.warn("DataInitializer: community '{}' not found — skipping admin seed", COMMUNITY_NAME);
            return;
        }

        var adminRole = roleRepository.findByName("ROLE_ADMIN").orElse(null);
        if (adminRole == null) {
            log.warn("DataInitializer: ROLE_ADMIN not found — skipping admin seed");
            return;
        }

        var existingAdmin = userRepository.findByCommunityIdAndEmail(community.getId(), ADMIN_EMAIL);
        if (existingAdmin.isPresent()) {
            // Always re-encode the password on startup to fix any bad hash from SQL migrations
            User admin = existingAdmin.get();
            admin.setPasswordHash(passwordEncoder.encode(ADMIN_PASSWORD));
            userRepository.save(admin);
            log.info("DataInitializer: admin password reset for '{}'", ADMIN_EMAIL);
            return;
        }

        User admin = User.builder()
                .communityId(community.getId())
                .email(ADMIN_EMAIL)
                .passwordHash(passwordEncoder.encode(ADMIN_PASSWORD))
                .firstName("Admin")
                .lastName("User")
                .isActive(true)
                .isEmailVerified(true)
                .build();

        admin.getRoles().add(adminRole);
        userRepository.save(admin);
        log.info("DataInitializer: admin user created for community '{}'", community.getName());
    }
}
