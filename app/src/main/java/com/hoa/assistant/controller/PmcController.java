package com.hoa.assistant.controller;

import com.hoa.assistant.dto.CreatePmcRequest;
import com.hoa.assistant.dto.PmcResponse;
import com.hoa.assistant.service.PmcService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/admin/pmcs")
@RequiredArgsConstructor
@CrossOrigin(origins = "*")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public class PmcController {

    private final PmcService pmcService;

    @PostMapping
    public ResponseEntity<PmcResponse> createPmc(@Valid @RequestBody CreatePmcRequest request) {
        return ResponseEntity.ok(pmcService.createPmc(request));
    }

    @GetMapping
    public ResponseEntity<List<PmcResponse>> listPmcs() {
        return ResponseEntity.ok(pmcService.listAllPmcs());
    }

    @GetMapping("/{id}")
    public ResponseEntity<PmcResponse> getPmc(@PathVariable Long id) {
        return ResponseEntity.ok(pmcService.getPmc(id));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<PmcResponse> updatePmc(
            @PathVariable Long id,
            @RequestBody CreatePmcRequest request) {
        return ResponseEntity.ok(pmcService.updatePmc(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deactivatePmc(@PathVariable Long id) {
        pmcService.deactivatePmc(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * Assign a community to this PMC.
     * Any existing active assignment for that community is automatically deactivated first.
     */
    @PostMapping("/{pmcId}/communities/{communityId}")
    public ResponseEntity<PmcResponse> assignCommunity(
            @PathVariable Long pmcId,
            @PathVariable Long communityId,
            @RequestParam(required = false) String notes) {
        return ResponseEntity.ok(pmcService.assignCommunity(pmcId, communityId, notes));
    }

    /**
     * Remove the active assignment of a community from this PMC.
     */
    @DeleteMapping("/{pmcId}/communities/{communityId}")
    public ResponseEntity<Void> unassignCommunity(
            @PathVariable Long pmcId,
            @PathVariable Long communityId) {
        pmcService.unassignCommunity(pmcId, communityId);
        return ResponseEntity.noContent().build();
    }
}
