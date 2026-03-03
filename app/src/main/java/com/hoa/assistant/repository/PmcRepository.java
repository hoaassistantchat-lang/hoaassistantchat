package com.hoa.assistant.repository;

import com.hoa.assistant.model.PropertyManagementCompany;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PmcRepository extends JpaRepository<PropertyManagementCompany, Long> {

    List<PropertyManagementCompany> findByIsActiveTrueOrderByCompanyNameAsc();

    List<PropertyManagementCompany> findAllByOrderByCompanyNameAsc();
}
