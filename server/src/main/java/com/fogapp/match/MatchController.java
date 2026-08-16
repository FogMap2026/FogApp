package com.fogapp.match;

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
 * 매칭(동행 요청) CRUD 뼈대(#1-8) + 성향 유사도 기반 후보 추천(#37).
 * 요청·조회·상태변경·취소는 인증된 본인 명의로만 할 수 있다(#52) — userId는 클라이언트 입력이 아니라
 * {@link AuthUser}(검증된 토큰)에서 가져온다.
 */
@RestController
@RequestMapping("/api/matches")
public class MatchController {

    private final MatchService matchService;

    public MatchController(MatchService matchService) {
        this.matchService = matchService;
    }

    @PostMapping
    public ResponseEntity<MatchResponse> create(@AuthenticationPrincipal AuthUser me,
                                                  @Valid @RequestBody MatchCreateRequest request) {
        Match match = matchService.request(me.userId(), request.addresseeId());
        return ResponseEntity.status(HttpStatus.CREATED).body(matchService.withCounterpart(match, me.userId()));
    }

    @GetMapping("/{id}")
    public MatchResponse get(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        return matchService.withCounterpart(matchService.get(id), me.userId());
    }

    /** 내 매칭 전체(보낸 것 + 받은 것, 5-2). 각 항목에 상대방 정보와 방향을 함께 내려준다. */
    @GetMapping
    public List<MatchResponse> listForUser(@AuthenticationPrincipal AuthUser me) {
        return matchService.withCounterparts(matchService.listForUser(me.userId()), me.userId());
    }

    @GetMapping("/candidates")
    public List<MatchCandidate> recommendCandidates(
            @AuthenticationPrincipal AuthUser me,
            @RequestParam(defaultValue = "10") int limit) {
        return matchService.recommendCandidates(me.userId(), limit);
    }

    @PatchMapping("/{id}/status")
    public MatchResponse updateStatus(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                                       @Valid @RequestBody MatchStatusUpdateRequest request) {
        Match match = matchService.updateStatus(me.userId(), id, request.status());
        return matchService.withCounterpart(match, me.userId());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        matchService.delete(me.userId(), id);
        return ResponseEntity.noContent().build();
    }
}
