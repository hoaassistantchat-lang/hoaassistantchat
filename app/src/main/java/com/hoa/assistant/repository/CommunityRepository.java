package com.hoa.assistant.repository;

import com.hoa.assistant.model.Community;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CommunityRepository extends JpaRepository<Community, Long> {
    Optional<Community> findByName(String name);
    /** Returns the oldest community matching the name — safe when duplicates exist */
    Optional<Community> findFirstByNameOrderByIdAsc(String name);
    Optional<Community> findBySlug(String slug);
    boolean existsBySlug(String slug);
    List<Community> findAllByName(String name);
}
