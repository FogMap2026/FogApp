package com.fogapp.conquest;

import java.util.List;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

/**
 * 정복률 API(#51). 사용자는 인증 필터가 세운 {@link AuthUser} 에서만 얻는다 — 요청으로 받지 않는다.
 */
@RestController
@RequestMapping("/api/conquest")
public class ConquestController {

    private final ConquestService conquestService;

    public ConquestController(ConquestService conquestService) {
        this.conquestService = conquestService;
    }

    /**
     * 내 지역별 정복률.
     *
     * <p>지역 단위는 <b>시/군/구</b>다(팀 결정). 앱은 지도에서 보고 있는 지역의
     * {@code regionCode} 로 골라 상단 정보 바에 표시한다 — 스팟 조회 응답의
     * {@code areaCode}/{@code sigunguCode} 를 {@code "{areaCode}-{sigunguCode}"} 로
     * 이으면 같은 코드가 된다.</p>
     */
    @GetMapping
    public List<ConquestResponse> myConquest(@AuthenticationPrincipal AuthUser me) {
        return conquestService.myConquest(me.userId());
    }
}
