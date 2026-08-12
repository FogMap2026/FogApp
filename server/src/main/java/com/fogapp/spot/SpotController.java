package com.fogapp.spot;

import java.util.List;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

/**
 * 스팟 조회 API(#7, #50). Phase 2 지도 화면이 안개 아래 스팟을 로드하는 소비 지점.
 *
 * <p>응답의 해금 여부는 <b>로그인한 사용자 기준</b>이다. 사용자는 인증 필터가 세운
 * {@link AuthUser} 에서 얻는다 — 요청으로 받으면 남의 해금 상태를 조회할 수 있다.</p>
 */
@RestController
@RequestMapping("/api/spots")
public class SpotController {

    private final SpotQueryService spotQueryService;

    public SpotController(SpotQueryService spotQueryService) {
        this.spotQueryService = spotQueryService;
    }

    /** 지역 코드별 조회. 예) GET /api/spots?region=35&page=0&size=50 */
    @GetMapping
    public PageResponse<SpotResponse> byRegion(
            @AuthenticationPrincipal AuthUser me,
            @RequestParam String region,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return spotQueryService.findByRegion(me.userId(), region, page, size);
    }

    /** 현재 위치 반경 조회. 예) GET /api/spots/nearby?lat=37.57&lng=126.98&radius=3000 */
    @GetMapping("/nearby")
    public List<SpotResponse> nearby(
            @AuthenticationPrincipal AuthUser me,
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(defaultValue = "3000") double radius) {
        return spotQueryService.findNearby(me.userId(), lat, lng, radius);
    }
}
