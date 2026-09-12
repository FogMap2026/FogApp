package com.fogapp.journey;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 걸어온 자리(#131) — 안개를 15m 반경으로 걷는 데 쓰는 궤적.
 *
 * <p>{@code userId} 는 <b>요청 본문에서 받지 않는다.</b> 인증 필터가 세운 현재 사용자를
 * 쓴다 — 남의 명의로 궤적을 심는 경로를 만들지 않는다(#52 에서 발자취·매칭이 겪은 문제).</p>
 */
@RestController
@RequestMapping("/api/journeys")
public class JourneyController {

    private final JourneyService journeyService;

    public JourneyController(JourneyService journeyService) {
        this.journeyService = journeyService;
    }

    /**
     * 궤적을 모아 올린다. 재전송해도 안전하다(서버가 멱등).
     *
     * <p>예) {@code POST /api/journeys/points}
     * {@code { "points": [ { "lat": 37.5, "lng": 127.0, "recordedAt": "2026-09-10T…Z" } ] }}</p>
     */
    @PostMapping("/points")
    public ResponseEntity<Map<String, Integer>> record(
            @AuthenticationPrincipal AuthUser me,
            @Valid @RequestBody JourneyPointsUploadRequest request) {
        int saved = journeyService.record(me.userId(), request.points());
        // 「보낸 수」와 「저장된 수」를 함께 준다 — 앱이 재전송으로 0 이 나오는 것을
        // 실패로 오해하지 않게 한다. 0 은 「이미 다 있다」는 정상 응답이다.
        return ResponseEntity.ok(Map.of(
                "received", request.points().size(),
                "saved", saved));
    }

    /** 내 궤적. 지도 진입 시 안개 구멍을 복원하는 데 쓴다. */
    @GetMapping
    public List<JourneyPointResponse> mine(
            @AuthenticationPrincipal AuthUser me,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to) {
        return journeyService.mine(me.userId(), from, to);
    }
}
