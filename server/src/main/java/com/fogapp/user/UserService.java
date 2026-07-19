package com.fogapp.user;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fogapp.auth.VerifiedToken;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
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
}
