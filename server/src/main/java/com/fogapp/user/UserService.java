package com.fogapp.user;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
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
     *   <li><b>DB 먼저</b> — {@code users} 한 행을 지우면 visits·footprints·matches·footprint_likes 가
     *       전부 따라간다(V1·V3 의 {@code ON DELETE CASCADE}). 이게 파기의 <b>본체</b>이고,
     *       실패하면 아무것도 지우지 않은 채로 끝난다 — 이용자가 다시 누르면 된다</li>
     *   <li><b>사진</b> — 경로가 {@code firebaseUid} 로만 정해지므로 DB 행이 없어도 찾을 수 있다.
     *       위에서 잡아둔 지역변수를 쓴다</li>
     *   <li><b>인증 계정</b> — 마지막</li>
     * </ol>
     *
     * <p>🔴 <b>{@code @Transactional} 을 다시 붙이지 말 것</b>(#182 리뷰). 파일 walk 와
     * Firebase 네트워크 호출이 트랜잭션 안에 있으면 그동안 HikariCP 커넥션이 묶인다 —
     * Firebase 가 느리거나 사진이 많으면 홀드가 길어지고, 몰리면 풀이 마른다.
     * {@code userRepository.delete} 는 <b>그 자체로 트랜잭션</b>이고(리포지토리 기본),
     * 한 행 삭제 + CASCADE 라 원자성은 DB 가 진다.</p>
     *
     * <p>⚠️ {@code NOT_SUPPORTED} 인 이유 — 이 클래스에 {@code @Transactional(readOnly = true)}
     * 가 걸려 있어 <b>아무것도 안 붙이면 읽기 전용 트랜잭션이 열린다.</b> 명시적으로
     * 밖에 서야 {@code userRepository.delete} 가 자기 트랜잭션을 연다.</p>
     *
     * <p>🔴 순서를 <b>인증 계정 먼저</b>로 뒤집지 말 것. 어느 쪽이든 실패하면 무언가가
     * 남는데, 남는 것의 <b>무게가 다르다</b> — 지금 순서에서 남는 것은 Firebase 의
     * 이메일 한 줄이고(이용자가 다시 로그인하면 <b>빈 계정</b>으로 시작한다), 뒤집으면
     * 남는 것은 <b>좌표·사진·글 전부인데 이용자는 로그인조차 못 해</b> 스스로 지울
     * 방법이 없다.</p>
     *
     * <p>⛔ 되돌릴 수 없다. 호출부(컨트롤러)가 본인 확인을 이미 마친 뒤여야 한다 —
     * {@code userId} 는 인증 필터가 세운 현재 사용자에서만 온다.</p>
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public void withdraw(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다."));
        String firebaseUid = user.getFirebaseUid();

        userRepository.delete(user);
        int photos = photoStorage.deleteAllOf(firebaseUid);
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
