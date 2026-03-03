package com.hoa.assistant.security;

import com.hoa.assistant.model.User;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.stream.Collectors;

/**
 * Spring Security UserDetails wrapper for our User entity.
 * Carries both the standard auth fields AND tenant context (communityId).
 */
@Getter
public class HoaUserDetails implements UserDetails {

    private final Long userId;
    private final Long communityId;
    private final String email;
    private final String password;
    private final boolean active;
    private final Collection<? extends GrantedAuthority> authorities;

    public HoaUserDetails(User user) {
        this.userId = user.getId();
        this.communityId = user.getCommunityId();
        this.email = user.getEmail();
        this.password = user.getPasswordHash();
        this.active = Boolean.TRUE.equals(user.getIsActive());
        this.authorities = user.getRoles().stream()
                .map(role -> new SimpleGrantedAuthority(role.getName()))
                .collect(Collectors.toSet());
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public String getPassword() {
        return password;
    }

    /** Spring Security uses getUsername() as the principal identifier */
    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isAccountNonExpired() { return true; }

    @Override
    public boolean isAccountNonLocked() { return active; }

    @Override
    public boolean isCredentialsNonExpired() { return true; }

    @Override
    public boolean isEnabled() { return active; }
}
