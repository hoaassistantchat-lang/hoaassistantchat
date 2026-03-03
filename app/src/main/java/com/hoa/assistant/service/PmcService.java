package com.hoa.assistant.service;

import com.hoa.assistant.dto.CreatePmcRequest;
import com.hoa.assistant.dto.PmcResponse;
import com.hoa.assistant.exception.BusinessException;
import com.hoa.assistant.exception.ResourceNotFoundException;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.model.CommunityPmcAssignment;
import com.hoa.assistant.model.PropertyManagementCompany;
import com.hoa.assistant.repository.CommunityPmcAssignmentRepository;
import com.hoa.assistant.repository.CommunityRepository;
import com.hoa.assistant.repository.PmcRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class PmcService {

    private final PmcRepository pmcRepository;
    private final CommunityPmcAssignmentRepository assignmentRepository;
    private final CommunityRepository communityRepository;

    // ── CRUD ─────────────────────────────────────────────────────

    @Transactional
    public PmcResponse createPmc(CreatePmcRequest request) {
        PropertyManagementCompany pmc = PropertyManagementCompany.builder()
                .companyName(request.getCompanyName())
                .address(request.getAddress())
                .city(request.getCity())
                .state(request.getState())
                .zip(request.getZip())
                .website(request.getWebsite())
                .email(request.getEmail())
                .phoneMain(request.getPhoneMain())
                .phoneSecondary(request.getPhoneSecondary())
                .phoneMobile(request.getPhoneMobile())
                .contact1Name(request.getContact1Name())
                .contact1Title(request.getContact1Title())
                .contact1Phone(request.getContact1Phone())
                .contact1Email(request.getContact1Email())
                .contact2Name(request.getContact2Name())
                .contact2Title(request.getContact2Title())
                .contact2Phone(request.getContact2Phone())
                .contact2Email(request.getContact2Email())
                .contact3Name(request.getContact3Name())
                .contact3Title(request.getContact3Title())
                .contact3Phone(request.getContact3Phone())
                .contact3Email(request.getContact3Email())
                .notes(request.getNotes())
                .isActive(true)
                .build();

        pmc = pmcRepository.save(pmc);
        log.info("Created PMC '{}' id={}", pmc.getCompanyName(), pmc.getId());
        return toResponse(pmc);
    }

    public List<PmcResponse> listAllPmcs() {
        return pmcRepository.findAllByOrderByCompanyNameAsc()
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public PmcResponse getPmc(Long id) {
        PropertyManagementCompany pmc = pmcRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PMC not found: " + id));
        return toResponse(pmc);
    }

    @Transactional
    public PmcResponse updatePmc(Long id, CreatePmcRequest request) {
        PropertyManagementCompany pmc = pmcRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PMC not found: " + id));

        if (request.getCompanyName() != null) pmc.setCompanyName(request.getCompanyName());
        if (request.getAddress()     != null) pmc.setAddress(request.getAddress());
        if (request.getCity()        != null) pmc.setCity(request.getCity());
        if (request.getState()       != null) pmc.setState(request.getState());
        if (request.getZip()         != null) pmc.setZip(request.getZip());
        if (request.getWebsite()     != null) pmc.setWebsite(request.getWebsite());
        if (request.getEmail()       != null) pmc.setEmail(request.getEmail());
        if (request.getPhoneMain()      != null) pmc.setPhoneMain(request.getPhoneMain());
        if (request.getPhoneSecondary() != null) pmc.setPhoneSecondary(request.getPhoneSecondary());
        if (request.getPhoneMobile()    != null) pmc.setPhoneMobile(request.getPhoneMobile());
        if (request.getContact1Name()  != null) pmc.setContact1Name(request.getContact1Name());
        if (request.getContact1Title() != null) pmc.setContact1Title(request.getContact1Title());
        if (request.getContact1Phone() != null) pmc.setContact1Phone(request.getContact1Phone());
        if (request.getContact1Email() != null) pmc.setContact1Email(request.getContact1Email());
        if (request.getContact2Name()  != null) pmc.setContact2Name(request.getContact2Name());
        if (request.getContact2Title() != null) pmc.setContact2Title(request.getContact2Title());
        if (request.getContact2Phone() != null) pmc.setContact2Phone(request.getContact2Phone());
        if (request.getContact2Email() != null) pmc.setContact2Email(request.getContact2Email());
        if (request.getContact3Name()  != null) pmc.setContact3Name(request.getContact3Name());
        if (request.getContact3Title() != null) pmc.setContact3Title(request.getContact3Title());
        if (request.getContact3Phone() != null) pmc.setContact3Phone(request.getContact3Phone());
        if (request.getContact3Email() != null) pmc.setContact3Email(request.getContact3Email());
        if (request.getNotes()       != null) pmc.setNotes(request.getNotes());

        pmc = pmcRepository.save(pmc);
        log.info("Updated PMC id={}", id);
        return toResponse(pmc);
    }

    @Transactional
    public void deactivatePmc(Long id) {
        PropertyManagementCompany pmc = pmcRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PMC not found: " + id));
        pmc.setIsActive(false);
        pmcRepository.save(pmc);
        log.info("Deactivated PMC id={}", id);
    }

    // ── Community Assignment ──────────────────────────────────────

    /**
     * Assign a community to a PMC.
     * Any currently active assignment for that community is first deactivated
     * (preserving history), then a new active one is created.
     */
    @Transactional
    public PmcResponse assignCommunity(Long pmcId, Long communityId, String notes) {
        pmcRepository.findById(pmcId)
                .orElseThrow(() -> new ResourceNotFoundException("PMC not found: " + pmcId));
        communityRepository.findById(communityId)
                .orElseThrow(() -> new ResourceNotFoundException("Community not found: " + communityId));

        // Deactivate existing active assignment for this community (from any PMC)
        assignmentRepository.findByCommunityIdAndIsActiveTrue(communityId).ifPresent(existing -> {
            if (existing.getPmcId().equals(pmcId)) {
                throw new BusinessException("Community is already assigned to this PMC", "ALREADY_ASSIGNED");
            }
            existing.setIsActive(false);
            existing.setUnassignedAt(LocalDateTime.now());
            assignmentRepository.save(existing);
            log.info("Deactivated previous assignment id={} for community {}", existing.getId(), communityId);
        });

        CommunityPmcAssignment assignment = CommunityPmcAssignment.builder()
                .communityId(communityId)
                .pmcId(pmcId)
                .isActive(true)
                .assignedAt(LocalDateTime.now())
                .notes(notes)
                .build();
        assignmentRepository.save(assignment);
        log.info("Assigned community {} to PMC {}", communityId, pmcId);
        return toResponse(pmcRepository.findById(pmcId).get());
    }

    /**
     * Remove active assignment of a community from a PMC (records unassignment timestamp).
     */
    @Transactional
    public void unassignCommunity(Long pmcId, Long communityId) {
        CommunityPmcAssignment assignment = assignmentRepository
                .findByCommunityIdAndIsActiveTrue(communityId)
                .filter(a -> a.getPmcId().equals(pmcId))
                .orElseThrow(() -> new BusinessException(
                        "Community " + communityId + " is not actively assigned to PMC " + pmcId,
                        "NOT_ASSIGNED"));

        assignment.setIsActive(false);
        assignment.setUnassignedAt(LocalDateTime.now());
        assignmentRepository.save(assignment);
        log.info("Unassigned community {} from PMC {}", communityId, pmcId);
    }

    // ── Mapping ───────────────────────────────────────────────────

    private PmcResponse toResponse(PropertyManagementCompany pmc) {
        List<PmcResponse.AssignedCommunity> communities =
                assignmentRepository.findByPmcId(pmc.getId()).stream()
                        .map(a -> {
                            String name = communityRepository.findById(a.getCommunityId())
                                    .map(Community::getName)
                                    .orElse("Unknown");
                            return PmcResponse.AssignedCommunity.builder()
                                    .assignmentId(a.getId())
                                    .communityId(a.getCommunityId())
                                    .communityName(name)
                                    .isActive(a.getIsActive())
                                    .assignedAt(a.getAssignedAt())
                                    .unassignedAt(a.getUnassignedAt())
                                    .build();
                        })
                        .toList();

        return PmcResponse.builder()
                .id(pmc.getId())
                .companyName(pmc.getCompanyName())
                .address(pmc.getAddress())
                .city(pmc.getCity())
                .state(pmc.getState())
                .zip(pmc.getZip())
                .website(pmc.getWebsite())
                .email(pmc.getEmail())
                .phoneMain(pmc.getPhoneMain())
                .phoneSecondary(pmc.getPhoneSecondary())
                .phoneMobile(pmc.getPhoneMobile())
                .contact1Name(pmc.getContact1Name())
                .contact1Title(pmc.getContact1Title())
                .contact1Phone(pmc.getContact1Phone())
                .contact1Email(pmc.getContact1Email())
                .contact2Name(pmc.getContact2Name())
                .contact2Title(pmc.getContact2Title())
                .contact2Phone(pmc.getContact2Phone())
                .contact2Email(pmc.getContact2Email())
                .contact3Name(pmc.getContact3Name())
                .contact3Title(pmc.getContact3Title())
                .contact3Phone(pmc.getContact3Phone())
                .contact3Email(pmc.getContact3Email())
                .isActive(pmc.getIsActive())
                .notes(pmc.getNotes())
                .createdAt(pmc.getCreatedAt())
                .communities(communities)
                .build();
    }
}
