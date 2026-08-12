package com.fogapp.user;

/**
 * 다른 모듈에 노출하는 <b>공개 사용자 정보</b>(#71).
 *
 * <p>발자취 카드처럼 "누가 썼는지"를 보여줘야 하는 화면이 쓴다. 이메일·성향 점수 등
 * {@link User} 의 나머지 필드는 <b>일부러 담지 않는다</b> — 남에게 보여도 되는 최소한만
 * 골라 두면, 새 화면이 생길 때마다 무엇을 공개할지 다시 판단할 필요가 없다.</p>
 *
 * <p>{@code nickname} 은 null 일 수 있다. 가입 직후 닉네임을 정하지 않은 사용자가 있다 —
 * 화면에서 대체 문구를 쓸 것.</p>
 */
public record UserSummary(Long id, String nickname, String profileImageUrl) {
}
