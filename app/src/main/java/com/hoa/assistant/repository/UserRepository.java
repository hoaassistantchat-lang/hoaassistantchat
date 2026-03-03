package com.hoa.assistant.repository;

import com.hoa.assistant.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByCommunityIdAndEmail(Long communityId, String email);

    Optional<User> findByEmail(String email);

    boolean existsByCommunityIdAndEmail(Long communityId, String email);

    long countByCommunityIdAndRoles_Name(Long communityId, String roleName);

    java.util.List<User> findByCommunityIdOrderByLastNameAscFirstNameAsc(Long communityId);
}
