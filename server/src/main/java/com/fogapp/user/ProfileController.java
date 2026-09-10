package com.fogapp.user;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 내 프로필 조회/수정(#4). 인증 필터가 세운 현재 사용자(AuthUser) 기준으로 동작한다.
 */
@RestController
@RequestMapping("/api/profile")
public class ProfileController {

    private final UserService userService;
    private final ObjectMapper objectMapper;

    public ProfileController(UserService userService, ObjectMapper objectMapper) {
        this.userService = userService;
        this.objectMapper = objectMapper;
    }

    @GetMapping
    public ProfileResponse me(@AuthenticationPrincipal AuthUser me) {
        return ProfileResponse.from(userService.get(me.userId()), objectMapper);
    }

    @PatchMapping
    public ProfileResponse update(@AuthenticationPrincipal AuthUser me,
                                  @Valid @RequestBody ProfileUpdateRequest request) {
        return ProfileResponse.from(
                userService.updateProfile(me.userId(), request.nickname(), request.profileImageUrl()),
                objectMapper);
    }

    @PatchMapping("/personality")
    public ResponseEntity<Void> updatePersonality(@AuthenticationPrincipal AuthUser me,
                                                   @Valid @RequestBody PersonalityUpdateRequest request) {
        userService.updatePersonality(me.userId(), request.personalityType(), request.personalityScores());
        return ResponseEntity.noContent().build();
    }

    /**
     * 개인정보·위치정보 수집 동의를 기록한다(#152). {@link ConsentUpdateRequest}가
     * 두 항목 다 {@code true}만 허용하므로, 여기 도달했다는 것 자체가 전체 동의다.
     */
    @PatchMapping("/consent")
    public ProfileResponse updateConsent(@AuthenticationPrincipal AuthUser me,
                                          @Valid @RequestBody ConsentUpdateRequest request) {
        return ProfileResponse.from(
                userService.recordConsent(me.userId(), request.privacy(), request.location()),
                objectMapper);
    }

    /**
     * 회원 탈퇴(#182). 계정과 관련 정보를 <b>즉시</b> 파기한다.
     *
     * <p>⛔ <b>되돌릴 수 없다.</b> 지우는 대상은 인증 필터가 세운 <b>현재 사용자</b>뿐이다 —
     * 경로나 본문으로 {@code userId} 를 받지 않는다(#52 에서 발자취·매칭이 겪은 문제).</p>
     *
     * <p>방침 4장·7장이 「11장의 연락처로 요청」이라고 적어둔 것은, 그때 앱에 이 기능이
     * 없었기 때문이다. 문구는 이 변경과 함께 고친다.</p>
     */
    @DeleteMapping
    public ResponseEntity<Void> withdraw(@AuthenticationPrincipal AuthUser me) {
        userService.withdraw(me.userId());
        return ResponseEntity.noContent().build();
    }
}
