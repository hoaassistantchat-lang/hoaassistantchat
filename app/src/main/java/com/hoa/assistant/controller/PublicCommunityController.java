package com.hoa.assistant.controller;

import com.hoa.assistant.dto.CommunityListResponse;
import com.hoa.assistant.service.CommunityService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Public-facing controller for community information.
 * No authentication required — used by the embeddable chat widget.
 */
@Slf4j
@RestController
@RequestMapping("/api/public/communities")
@RequiredArgsConstructor
public class PublicCommunityController {

    private final CommunityService communityService;

    @GetMapping
    public ResponseEntity<List<CommunityListResponse>> getActiveCommunities() {
        log.info("Fetching active communities for public widget");
        List<CommunityListResponse> communities = communityService.getActiveCommunities();
        return ResponseEntity.ok(communities);
    }
}
