package com.hoa.assistant.service;

import com.hoa.assistant.dto.CreateResidentRequest;
import com.hoa.assistant.dto.admin.AdminDashboardResponse;
import com.hoa.assistant.dto.admin.ResidentSummary;
import com.hoa.assistant.dto.admin.UpdateResidentRequest;
import com.hoa.assistant.exception.BusinessException;
import com.hoa.assistant.exception.ResourceNotFoundException;
import com.hoa.assistant.model.Community;
import com.hoa.assistant.model.Role;
import com.hoa.assistant.model.User;
import com.hoa.assistant.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminService {

    private final TicketRepository ticketRepository;
    private final UserRepository userRepository;
    private final DocumentRepository documentRepository;
    private final CommunityRepository communityRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;

    // --------------------------------------------------------
    // DASHBOARD ANALYTICS
    // --------------------------------------------------------
    public AdminDashboardResponse getDashboard(Long communityId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> new ResourceNotFoundException("Community not found"));

        long totalTickets    = ticketRepository.findByCommunityId(communityId).size();
        long openTickets     = ticketRepository.findByCommunityIdAndStatus(communityId, "open").size();
        long inProgressCount = ticketRepository.findByCommunityIdAndStatus(communityId, "in_progress").size();
        long resolvedCount   = ticketRepository.findByCommunityIdAndStatus(communityId, "resolved").size()
                             + ticketRepository.findByCommunityIdAndStatus(communityId, "closed").size();

        long totalDocs     = documentRepository.countByCommunityIdAndIsArchivedFalse(communityId);
        long processedDocs = documentRepository.findByCommunityIdAndProcessed(communityId, true).size();

        long totalResidents  = userRepository.count(); // scoped to community via role filter below
        long activeResidents = userRepository.countByCommunityIdAndRoles_Name(communityId, "ROLE_RESIDENT");

        return AdminDashboardResponse.builder()
                .communityName(community.getName())
                .communitySlug(community.getSlug())
                .planTier(community.getPlanTier())
                .totalTickets(totalTickets)
                .openTickets(openTickets)
                .inProgressTickets(inProgressCount)
                .resolvedTickets(resolvedCount)
                .totalDocuments(totalDocs)
                .processedDocuments(processedDocs)
                .totalResidents(activeResidents)
                .activeResidents(activeResidents)
                .build();
    }

    // --------------------------------------------------------
    // RESIDENTS
    // --------------------------------------------------------
    public List<ResidentSummary> getResidents(Long communityId) {
        return userRepository.findByCommunityIdOrderByLastNameAscFirstNameAsc(communityId)
                .stream()
                .map(this::toResidentSummary)
                .toList();
    }

    /**
     * Admin-creates a resident account for a community.
     * A random temp password is set; the resident can reset it via the forgot-password flow.
     * Email verification is skipped (admin vouches for the email).
     */
    @Transactional
    public ResidentSummary createResident(Long communityId, CreateResidentRequest request) {
        communityRepository.findById(communityId)
                .orElseThrow(() -> new ResourceNotFoundException("Community not found: " + communityId));

        if (userRepository.existsByCommunityIdAndEmail(communityId, request.getEmail())) {
            throw new BusinessException("Resident with email '" + request.getEmail() + "' already exists in this community", "DUPLICATE_EMAIL");
        }

        Role residentRole = roleRepository.findByName("ROLE_RESIDENT")
                .orElseThrow(() -> new ResourceNotFoundException("ROLE_RESIDENT not found"));

        String tempPassword = "HOA@" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);

        User user = User.builder()
                .communityId(communityId)
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(tempPassword))
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .unitNumber(request.getUnitNumber())
                .phone(request.getPhone())
                .isActive(true)
                .isEmailVerified(true)
                .roles(Set.of(residentRole))
                .build();

        user = userRepository.save(user);
        log.info("Admin created resident {} in community {}", user.getEmail(), communityId);
        return toResidentSummary(user);
    }

    public ResidentSummary getResident(Long communityId, Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Resident not found"));
        if (!communityId.equals(user.getCommunityId())) {
            throw new ResourceNotFoundException("Resident not found in this community");
        }
        return toResidentSummary(user);
    }

    @Transactional
    public ResidentSummary updateResident(Long communityId, Long userId, UpdateResidentRequest req) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Resident not found"));
        if (!communityId.equals(user.getCommunityId())) {
            throw new ResourceNotFoundException("Resident not found in this community");
        }
        if (req.getIsActive() != null)     user.setIsActive(req.getIsActive());
        if (req.getFirstName() != null)    user.setFirstName(req.getFirstName());
        if (req.getLastName() != null)     user.setLastName(req.getLastName());
        if (req.getUnitNumber() != null)   user.setUnitNumber(req.getUnitNumber());
        if (req.getPhone() != null)        user.setPhone(req.getPhone());
        user = userRepository.save(user);
        log.info("Admin updated resident {} in community {}", userId, communityId);
        return toResidentSummary(user);
    }

    private ResidentSummary toResidentSummary(User user) {
        return ResidentSummary.builder()
                .id(user.getId())
                .email(user.getEmail())
                .firstName(user.getFirstName())
                .lastName(user.getLastName())
                .unitNumber(user.getUnitNumber())
                .phone(user.getPhone())
                .isActive(user.getIsActive())
                .isEmailVerified(user.getIsEmailVerified())
                .createdAt(user.getCreatedAt())
                .lastLoginAt(user.getLastLoginAt())
                .roles(user.getRoles().stream().map(r -> r.getName()).toList())
                .build();
    }
}
