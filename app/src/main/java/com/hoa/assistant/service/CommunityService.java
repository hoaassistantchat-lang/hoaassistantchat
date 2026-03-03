package com.hoa.assistant.service;

import com.hoa.assistant.dto.CommunityListResponse;
import com.hoa.assistant.dto.CreateCommunityRequest;
import com.hoa.assistant.exception.BusinessException;
import com.hoa.assistant.exception.ResourceNotFoundException;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.repository.CommunityRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Service for community operations.
 * Encapsulates all community data access and business rules.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CommunityService {

    private final CommunityRepository communityRepository;

    /**
     * Returns all active communities as lightweight DTOs (id + name only).
     */
    public List<CommunityListResponse> getActiveCommunities() {
        log.info("Fetching active communities for public listing");
        return communityRepository.findAll().stream()
                .filter(c -> Boolean.TRUE.equals(c.getIsActive()))
                .map(c -> CommunityListResponse.builder()
                        .id(c.getId())
                        .name(c.getName())
                        .build())
                .toList();
    }

    /**
     * Returns ALL communities (active + inactive) with status.
     * Used by the admin community management table.
     */
    public List<CommunityListResponse> getAllCommunitiesWithStatus() {
        return communityRepository.findAll().stream()
                .map(c -> CommunityListResponse.builder()
                        .id(c.getId())
                        .name(c.getName())
                        .isActive(Boolean.TRUE.equals(c.getIsActive()))
                        .slug(c.getSlug())
                        .build())
                .toList();
    }

    /**
     * Returns only active communities as lightweight DTOs.
     * Used by PMC assignment dropdowns and other selectors.
     */
    public List<CommunityListResponse> getAllCommunities() {
        return communityRepository.findAll().stream()
                .filter(c -> Boolean.TRUE.equals(c.getIsActive()))
                .map(c -> CommunityListResponse.builder()
                        .id(c.getId())
                        .name(c.getName())
                        .isActive(true)
                        .slug(c.getSlug())
                        .build())
                .toList();
    }

    /**
     * Toggles a community's active status.
     */
    @Transactional
    public CommunityListResponse setActive(Long communityId, boolean active) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new ResourceNotFoundException("Community", communityId));
        community.setIsActive(active);
        community = communityRepository.save(community);
        return CommunityListResponse.builder()
                .id(community.getId())
                .name(community.getName())
                .isActive(community.getIsActive())
                .slug(community.getSlug())
                .build();
    }

    /**
     * Creates a new HOA community.
     * Slug is auto-generated from the name if not provided.
     */
    @Transactional
    public Community createCommunity(CreateCommunityRequest request) {
        String slug = (request.getSlug() != null && !request.getSlug().isBlank())
                ? request.getSlug().toLowerCase().replaceAll("[^a-z0-9-]", "-")
                : request.getName().toLowerCase().replaceAll("[^a-z0-9-]", "-");

        // Ensure unique slug by appending a suffix if needed
        String baseSlug = slug;
        int suffix = 1;
        while (communityRepository.existsBySlug(slug)) {
            slug = baseSlug + "-" + suffix++;
        }

        Community community = new Community();
        community.setName(request.getName());
        community.setSlug(slug);
        community.setTimeZone(request.getTimeZone() != null ? request.getTimeZone() : "America/Los_Angeles");
        community.setOfficeHours(request.getOfficeHours());
        community.setContactEmail(request.getContactEmail());
        community.setContactPhone(request.getContactPhone());
        community.setPaymentPortalUrl(request.getPaymentPortalUrl());
        community.setEmergencyContact(request.getEmergencyContact());
        community.setIsActive(true);

        community = communityRepository.save(community);
        log.info("Created community '{}' slug='{}' id={}", community.getName(), community.getSlug(), community.getId());
        return community;
    }

    /**
     * Validates that a community exists and is active.
     * Throws ResourceNotFoundException if not found, BusinessException if inactive.
     */
    public Community validateActiveCommunity(Long communityId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new ResourceNotFoundException("Community", communityId));

        if (!Boolean.TRUE.equals(community.getIsActive())) {
            throw new BusinessException("Community is not currently active", "COMMUNITY_INACTIVE");
        }

        return community;
    }
}
