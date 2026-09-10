package com.fogapp.user;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.auth.AuthAccountDeleter;
import com.fogapp.auth.VerifiedToken;
import com.fogapp.visit.VisitPhotoStorage;

@Service
@Transactional(readOnly = true)
public class UserService {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;
    private final VisitPhotoStorage photoStorage;
    private final AuthAccountDeleter accountDeleter;

    public UserService(UserRepository userRepository,
                       ObjectMapper objectMapper,
                       VisitPhotoStorage photoStorage,
                       AuthAccountDeleter accountDeleter) {
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
        this.photoStorage = photoStorage;
        this.accountDeleter = accountDeleter;
    }

    /**
     * 회원 탈퇴 — 계정과 관련 정보를 파기한다(#182).
     *
     * <p>방침 4장이 「요청을 확인한 <b>즉시</b> 계정과 관련 정보(방문 인증 기록·사진,
     * 발자취, 성향 결과)를 파기합니다」라고 약속한 그 동작이다. 그전까지는 이행 수단이
     * <b>운영 DB 에 손으로 치는 SQL</b> 뿐이었다 — {@code WHERE} 절 하나 틀리면 남의
     * 계정이 날아가고 되돌릴 수 없다.</p>
     *
     * <p><b>순서가 중요하다.</b></p>
     * <ol>
     *   <li><b>사진 먼저</b> — DB 행이 사라지면 어떤 파일이 이 사용자 것인지 알 방법이 없다.
     *       {@code visits} 는 {@code ON DELETE CASCADE} 라 행이 먼저 사라지면 경로를 잃는다</li>
     *   <li><b>DB</b> — {@code users} 한 행을 지우면 visits·footprints·matches·footprint_likes 가
     *       전부 따라간다(V1·V3 의 {@code ON DELETE CASCADE})</li>
     *   <li><b>인증 계정</b> — 마지막. 여기서 실패해도 우리 DB 의 개인정보는 이미 지워졌고,
     *       그게 파기의 본체다</li>
     * </ol>
     *
     * <p>⛔ 되돌릴 수 없다. 호출부(컨트롤러)가 본인 확인을 이미 마친 뒤여야 한다 —
     * {@code userId} 는 인증 필터가 세운 현재 사용자에서만 온다.</p>
     */
    @Transactional
    public void withdraw(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다."));
        String firebaseUid = user.getFirebaseUid();

        int photos = photoStorage.deleteAllOf(firebaseUid);
        userRepository.delete(user);
        boolean authDeleted = accountDeleter.delete(firebaseUid);

        log.info("회원 탈퇴 완료 userId={} photos={} authDeleted={}", userId, photos, authDeleted);
    }

    /**
     * 검증된 토큰으로 사용자를 조회하거나, 없으면 최초 로그인으로 보고 생성한다(업서트).
     */
    @Transactional
    public User upsertFromToken(VerifiedToken token) {
        return userRepository.findByFirebaseUid(token.uid())
                .orElseGet(() -> userRepository.save(
                        new User(token.uid(), token.email(), token.name(), token.picture())));
    }

    public User get(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다."));
    }

    @Transactional
    public User updateProfile(Long id, String nickname, String profileImageUrl) {
        User user = get(id);
        user.updateProfile(nickname, profileImageUrl);
        return user;
    }

    @Transactional
    public User updatePersonality(Long id, String personalityType, Map<String, Object> personalityScores) {
        User user = get(id);
        try {
            user.updatePersonality(personalityType, objectMapper.writeValueAsString(personalityScores));
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("personalityScores를 직렬화할 수 없습니다.", e);
        }
        return user;
    }

    /** 개인정보·위치정보 수집 동의를 기록한다(#152). */
    @Transactional
    public User recordConsent(Long id, boolean privacy, boolean location) {
        User user = get(id);
        user.recordConsent(privacy, location);
        return user;
    }
}
