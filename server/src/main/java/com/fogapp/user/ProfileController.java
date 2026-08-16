package com.fogapp.user;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
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
}
