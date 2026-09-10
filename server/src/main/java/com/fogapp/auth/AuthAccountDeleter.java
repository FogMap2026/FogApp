package com.fogapp.auth;

/**
 * 인증 제공자(Firebase) 쪽 계정을 지운다(#182 회원 탈퇴).
 *
 * <p>우리 {@code users} 행만 지우면 <b>탈퇴가 반쪽이다</b> — Firebase 에는 이메일이 그대로
 * 남고, 같은 계정으로 다시 로그인하면 새 {@code users} 행이 생긴다. 방침이 약속한
 * 「계정과 관련 정보를 파기」에 미치지 못한다.</p>
 *
 * <p>{@link TokenVerifier} 와 같은 모양으로 갈라둔다 — Firebase 가 꺼져 있는 환경(기본값·CI)
 * 에서도 서버가 뜨고 테스트가 돌아야 하기 때문이다.</p>
 */
public interface AuthAccountDeleter {

    /**
     * @return 실제로 지웠으면 {@code true}. 이미 없거나 제공자가 꺼져 있으면 {@code false}.
     */
    boolean delete(String firebaseUid);
}
