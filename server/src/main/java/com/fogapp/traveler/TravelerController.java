package com.fogapp.traveler;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Positive;

/**
 * 주변 여행자 익명 표시(#133, 6-3).
 *
 * <p>익명·30분 텀·스팟 기준 — 셋 중 하나만 풀어도 이 기능의 성격이 완전히
 * 달라진다. 응답에 {@code userId}·닉네임을 담지 않고, 좌표 대신 스팟 id 를
 * 쓰고, 30분 이내 갱신은 조회에서 빼는 것으로 이 셋을 코드 차원에서 강제한다.</p>
 *
 * <p>{@code @Validated} — {@code @RequestParam} 의 검증 어노테이션은 클래스에
 * 이게 없으면 조용히 무시된다. 좌표 범위(위도 ±90·경도 ±180) 검증이 실제로
 * 동작하려면 필요하다.</p>
 */
@RestController
@RequestMapping("/api/travelers")
@Validated
public class TravelerController {

    private final TravelerService travelerService;

    public TravelerController(TravelerService travelerService) {
        this.travelerService = travelerService;
    }

    /** 위치 게시(opt-in). 켤 때마다, 또는 30분마다 호출된다. */
    @PostMapping("/position")
    public ResponseEntity<Void> share(@AuthenticationPrincipal AuthUser me,
                                       @Valid @RequestBody TravelerPositionRequest request) {
        travelerService.share(me.userId(), request.lat(), request.lng());
        return ResponseEntity.noContent().build();
    }

    /** 공유 끄기. */
    @DeleteMapping("/position")
    public ResponseEntity<Void> stopSharing(@AuthenticationPrincipal AuthUser me) {
        travelerService.stopSharing(me.userId());
        return ResponseEntity.noContent().build();
    }

    /** 반경 내 익명 여행자 목록. */
    @GetMapping("/nearby")
    public List<NearbyTravelerResponse> nearby(
            @AuthenticationPrincipal AuthUser me,
            @RequestParam @DecimalMin("-90") @DecimalMax("90") double lat,
            @RequestParam @DecimalMin("-180") @DecimalMax("180") double lng,
            @RequestParam @Positive double radiusMeters) {
        return travelerService.nearby(me.userId(), lat, lng, radiusMeters);
    }
}
