package com.fogapp.footprint;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

/**
 * 발자취 CRUD 뼈대(#1-8). 인증 미들웨어(#4)가 붙기 전까지는 userId를 요청으로 직접 받는다.
 */
@RestController
@RequestMapping("/api/footprints")
public class FootprintController {

    private final FootprintService footprintService;

    public FootprintController(FootprintService footprintService) {
        this.footprintService = footprintService;
    }

    @PostMapping
    public ResponseEntity<FootprintResponse> create(@Valid @RequestBody FootprintCreateRequest request) {
        Footprint footprint = footprintService.create(
                request.userId(), request.spotId(), request.content(), request.photoUrl());
        return ResponseEntity.status(HttpStatus.CREATED).body(FootprintResponse.from(footprint));
    }

    @GetMapping("/{id}")
    public FootprintResponse get(@PathVariable Long id) {
        return FootprintResponse.from(footprintService.get(id));
    }

    @GetMapping
    public List<FootprintResponse> list(
            @RequestParam(required = false) Long spotId,
            @RequestParam(required = false) Long userId) {
        List<Footprint> footprints;
        if (spotId != null) {
            footprints = footprintService.listBySpot(spotId);
        } else if (userId != null) {
            footprints = footprintService.listByUser(userId);
        } else {
            throw new IllegalArgumentException("spotId 또는 userId 중 하나는 필수입니다.");
        }
        return footprints.stream().map(FootprintResponse::from).toList();
    }

    @PatchMapping("/{id}")
    public FootprintResponse update(@PathVariable Long id, @Valid @RequestBody FootprintUpdateRequest request) {
        return FootprintResponse.from(footprintService.update(id, request.content(), request.photoUrl()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        footprintService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
