package com.fogapp.footprint;

import java.time.OffsetDateTime;

import com.fogapp.user.User;

/**
 * 발자취 응답(#1-8, #23, #71/#72).
 *
 * <p>{@code authorNickname}/{@code authorProfileImageUrl}과 {@code likedByMe}는
 * 목록 조회(#71 카드 UI, #72 좋아요 UI)에 필요해 이번에 함께 추가했다 — 같은 응답
 * 객체를 두 이슈가 나눠서 건드리면 계약이 두 번 바뀐다.</p>
 */
public record FootprintResponse(
        Long id,
        Long userId,
        String authorNickname,
        String authorProfileImageUrl,
        Long spotId,
        String content,
        String photoUrl,
        int likeCount,
        boolean likedByMe,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    /**
     * 발자취를 응답으로 바꾼다.
     *
     * <p>{@code author}와 {@code likedByMe}를 반드시 받는다 — 기본값(익명·false) 오버로드를
     * 두면 호출부가 채워 넣는 걸 잊어도 컴파일이 통과해, 카드에 작성자가 안 보이거나
     * 좋아요 버튼이 항상 빈 채로 나가는 게 조용히 방치된다.</p>
     *
     * @param author 작성자. 탈퇴 등으로 없을 수 있어 null을 허용한다 — 그 경우 닉네임·이미지는 null.
     */
    public static FootprintResponse from(Footprint footprint, User author, boolean likedByMe) {
        return new FootprintResponse(
                footprint.getId(),
                footprint.getUserId(),
                author == null ? null : author.getNickname(),
                author == null ? null : author.getProfileImageUrl(),
                footprint.getSpotId(),
                footprint.getContent(),
                footprint.getPhotoUrl(),
                footprint.getLikeCount(),
                likedByMe,
                footprint.getCreatedAt(),
                footprint.getUpdatedAt()
        );
    }
}
