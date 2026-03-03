package com.hoa.assistant.service;

import com.hoa.assistant.dto.auth.*;
import com.hoa.assistant.exception.BusinessException;
import com.hoa.assistant.exception.ResourceNotFoundException;
import com.hoa.assistant.model.*;
import com.hoa.assistant.repository.*;
import com.hoa.assistant.security.HoaUserDetails;
import com.hoa.assistant.security.JwtUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final CommunityRepository communityRepository;
    private final PasswordResetTokenRepository resetTokenRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AuthenticationManager authenticationManager;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final EmailService emailService;

    // --------------------------------------------------------
    // LOGIN
    // --------------------------------------------------------
    @Transactional
    public AuthResponse login(LoginRequest request) {
        Authentication auth = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        HoaUserDetails userDetails = (HoaUserDetails) auth.getPrincipal();

        // Verify the user belongs to the requested community (if slug supplied)
        if (request.getCommunitySlug() != null) {
            Community community = getCommunityBySlug(request.getCommunitySlug());
            if (!community.getId().equals(userDetails.getCommunityId())) {
                throw new BusinessException("User does not belong to this community");
            }
        }

        // Update last login
        userRepository.findById(userDetails.getUserId()).ifPresent(user -> {
            user.setLastLoginAt(LocalDateTime.now());
            userRepository.save(user);
        });

        return buildAuthResponse(userDetails);
    }

    // --------------------------------------------------------
    // REGISTER (resident self-registration)
    // --------------------------------------------------------
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        Community community = getCommunityBySlug(request.getCommunitySlug());

        if (userRepository.existsByCommunityIdAndEmail(community.getId(), request.getEmail())) {
            throw new BusinessException("Email is already registered in this community");
        }

        Role residentRole = roleRepository.findByName("ROLE_RESIDENT")
                .orElseThrow(() -> new BusinessException("Default role not found"));

        User user = User.builder()
                .communityId(community.getId())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .firstName(request.getFirstName())
                .lastName(request.getLastName())
                .unitNumber(request.getUnitNumber())
                .phone(request.getPhone())
                .isActive(true)
                .isEmailVerified(false)
                .build();

        user.getRoles().add(residentRole);
        user = userRepository.save(user);
        log.info("New resident registered: {} in community {}", user.getEmail(), community.getName());

        // Send welcome email (Week 3-4)
        emailService.sendWelcomeEmail(user, community.getName());

        HoaUserDetails userDetails = new HoaUserDetails(user);
        return buildAuthResponse(userDetails);
    }

    // --------------------------------------------------------
    // REFRESH TOKEN
    // --------------------------------------------------------
    @Transactional
    public AuthResponse refreshToken(RefreshTokenRequest request) {
        RefreshToken storedToken = refreshTokenRepository.findByToken(request.getRefreshToken())
                .orElseThrow(() -> new BusinessException("Invalid refresh token"));

        if (!storedToken.isValid()) {
            throw new BusinessException("Refresh token is expired or revoked");
        }

        User user = userRepository.findById(storedToken.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Revoke old refresh tokens and issue new ones
        refreshTokenRepository.revokeAllByUserId(user.getId());

        HoaUserDetails userDetails = new HoaUserDetails(user);
        return buildAuthResponse(userDetails);
    }

    // --------------------------------------------------------
    // FORGOT PASSWORD
    // --------------------------------------------------------
    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        Community community = getCommunityBySlug(request.getCommunitySlug());

        userRepository.findByCommunityIdAndEmail(community.getId(), request.getEmail())
                .ifPresent(user -> {
                    String token = UUID.randomUUID().toString();
                    PasswordResetToken resetToken = PasswordResetToken.builder()
                            .userId(user.getId())
                            .token(token)
                            .expiresAt(LocalDateTime.now().plusHours(2))
                            .used(false)
                            .build();
                    resetTokenRepository.save(resetToken);

                    // Send password reset email (Week 3-4)
                    emailService.sendPasswordResetEmail(user, token, community.getName());
                    log.info("Password reset token generated for user: {} (email sent)", user.getEmail());
                });
        // Always return success to prevent email enumeration attacks
    }

    // --------------------------------------------------------
    // RESET PASSWORD
    // --------------------------------------------------------
    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        PasswordResetToken resetToken = resetTokenRepository.findByToken(request.getToken())
                .orElseThrow(() -> new BusinessException("Invalid or expired reset token"));

        if (!resetToken.isValid()) {
            throw new BusinessException("Reset token is expired or already used");
        }

        User user = userRepository.findById(resetToken.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        resetToken.setUsed(true);
        resetTokenRepository.save(resetToken);

        // Revoke all existing refresh tokens for security
        refreshTokenRepository.revokeAllByUserId(user.getId());
        log.info("Password reset successful for user: {}", user.getEmail());
    }

    // --------------------------------------------------------
    // LOGOUT
    // --------------------------------------------------------
    @Transactional
    public void logout(Long userId) {
        refreshTokenRepository.revokeAllByUserId(userId);
        SecurityContextHolder.clearContext();
    }

    // --------------------------------------------------------
    // HELPERS
    // --------------------------------------------------------
    private Community getCommunityBySlug(String slug) {
        return communityRepository.findBySlug(slug)
                .orElseThrow(() -> new ResourceNotFoundException("Community not found: " + slug));
    }

    private AuthResponse buildAuthResponse(HoaUserDetails userDetails) {
        String accessToken = jwtUtils.generateAccessToken(userDetails);
        String refreshTokenStr = jwtUtils.generateRefreshToken(userDetails);

        // Persist refresh token
        RefreshToken rt = RefreshToken.builder()
                .userId(userDetails.getUserId())
                .token(refreshTokenStr)
                .expiresAt(LocalDateTime.now()
                        .plusSeconds(jwtUtils.getRefreshExpirationMs() / 1000))
                .revoked(false)
                .build();
        refreshTokenRepository.save(rt);

        // Load full user for profile
        User user = userRepository.findById(userDetails.getUserId()).orElseThrow();
        Community community = communityRepository.findById(userDetails.getCommunityId()).orElse(null);

        AuthResponse.UserProfile profile = AuthResponse.UserProfile.builder()
                .id(user.getId())
                .communityId(user.getCommunityId())
                .communityName(community != null ? community.getName() : null)
                .email(user.getEmail())
                .firstName(user.getFirstName())
                .lastName(user.getLastName())
                .unitNumber(user.getUnitNumber())
                .roles(userDetails.getAuthorities().stream()
                        .map(a -> a.getAuthority()).toList())
                .build();

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshTokenStr)
                .tokenType("Bearer")
                .expiresIn(3600)   // 1 hour
                .user(profile)
                .build();
    }
}
