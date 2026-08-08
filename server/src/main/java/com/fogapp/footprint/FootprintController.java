package com.fogapp.footprint;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 발자취 CRUD 뼈대(#1-8) + 좋아요·공감(#23).
 * 작성·수정·삭제·좋아요는 인증된 본인 명의로만 할 수 있다(#52) — userId는 클라이언트 입력이 아니라
 * {@link AuthUser}(검증된 토큰)에서 가져온다.
 */
@RestController
@RequestMapping("/api/footprints")
public class FootprintController {

    private final FootprintService footprintService;
    private final FootprintLikeService footprintLikeService;

    public FootprintController(FootprintService footprintService, FootprintLikeService footprintLikeService) {
        this.footprintService = footprintService;
        this.footprintLikeService = footprintLikeService;
    }

    @PostMapping
    public ResponseEntity<FootprintResponse> create(@AuthenticationPrincipal AuthUser me,
                                                      @Valid @RequestBody FootprintCreateRequest request) {
        Footprint footprint = footprintService.create(
                me.userId(), request.spotId(), request.content(), request.photoUrl());
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
    public FootprintResponse update(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                                     @Valid @RequestBody FootprintUpdateRequest request) {
        return FootprintResponse.from(
                footprintService.update(me.userId(), id, request.content(), request.photoUrl()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        footprintService.delete(me.userId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/likes")
    public ResponseEntity<Void> like(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        footprintLikeService.like(id, me.userId());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}/likes")
    public ResponseEntity<Void> unlike(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        footprintLikeService.unlike(id, me.userId());
        return ResponseEntity.noContent().build();
    }
}
