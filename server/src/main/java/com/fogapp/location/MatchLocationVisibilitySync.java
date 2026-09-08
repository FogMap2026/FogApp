package com.fogapp.location;

/**
 * 실시간 위치 공유(Phase 6, #133)의 "누가 볼 수 있는가"를 Firestore 쪽에 반영한다.
 *
 * <p>위치 자체는 Firestore에 있는데({@code locations/{firebaseUid}}), 매칭 관계
 * ({@code matches.status})는 PostgreSQL에 있다. Firestore 보안 규칙은 PostgreSQL을
 * 볼 수 없으므로, "이 사람이 저 사람 위치를 읽어도 되는가"를 판정할 근거가 Firestore
 * 문서 안에도 있어야 한다 — 그래서 매칭 상태가 바뀔 때마다 이 인터페이스로 반영한다.</p>
 *
 * <p>실제 구현은 {@code firebase.enabled=true}일 때만 주입된다({@link
 * FirestoreMatchLocationVisibilitySync}). 그 밖(로컬 개발·CI)에서는 {@link
 * NoopMatchLocationVisibilitySync}가 대신 들어가 — {@link
 * com.fogapp.auth.TokenVerifier}/{@code DisabledTokenVerifier}와 같은 패턴이다.</p>
 */
public interface MatchLocationVisibilitySync {

    /**
     * 두 사용자가 서로의 위치를 볼 수 있게 한다 — 매칭이 수락됐을 때(#133).
     *
     * @param userAFirebaseUid 한쪽 사용자의 Firebase uid
     * @param userBFirebaseUid 다른 쪽 사용자의 Firebase uid
     */
    void grant(String userAFirebaseUid, String userBFirebaseUid);

    /**
     * 서로의 위치 접근을 끊는다 — 매칭이 취소·거절됐을 때(#133).
     *
     * <p>애초에 grant된 적이 없어도(예: pending 상태에서 바로 거절) 안전하게 호출할 수
     * 있어야 한다 — 없는 관계를 지우는 건 아무 일도 안 하는 것과 같다.</p>
     */
    void revoke(String userAFirebaseUid, String userBFirebaseUid);
}
