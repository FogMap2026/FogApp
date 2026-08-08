package com.fogapp.visit;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 방문 인증 API(#48). 탐험 루프의 "인증" 단계.
 *
 * <p>사용자는 항상 인증 필터가 세운 {@link AuthUser} 에서 얻는다 — 요청으로 받지 않는다.</p>
 */
@RestController
@RequestMapping("/api/visits")
public class VisitController {

    private final VisitService visitService;

    public VisitController(VisitService visitService) {
        this.visitService = visitService;
    }

    /** 방문 인증. 스팟 반경 밖이면 422, 이미 인증한 스팟이면 409. */
    @PostMapping
    public ResponseEntity<VisitResponse> verify(@AuthenticationPrincipal AuthUser me,
                                                @Valid @RequestBody VisitCreateRequest request) {
        Visit visit = visitService.verify(
                me.userId(), request.spotId(), request.photoUrl(), request.lat(), request.lng());
        return ResponseEntity.status(HttpStatus.CREATED).body(VisitResponse.from(visit));
    }

    /** 내 인증 목록(최신순). 앱이 걷힌 안개 영역과 해금된 스팟을 복원할 때 쓴다. */
    @GetMapping
    public List<VisitResponse> myVisits(@AuthenticationPrincipal AuthUser me) {
        return visitService.listByUser(me.userId()).stream()
                .map(VisitResponse::from)
                .toList();
    }
}
