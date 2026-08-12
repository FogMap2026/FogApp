package com.fogapp.footprint;

import java.time.OffsetDateTime;

import com.fogapp.user.UserSummary;

/**
 * 발자취 응답(#23, #71).
 *
 * <p>작성자의 닉네임·프로필 이미지를 함께 담는다. 카드에 "누가 썼는지"를 보여줘야 하는데
 * {@code userId} 만으로는 앱이 사용자마다 프로필을 따로 조회하게 되고(N+1), 애초에
 * {@code GET /api/profile} 은 <b>본인 것만</b> 내려주므로 남의 프로필을 볼 방법이 없다.</p>
 *
 * <p>{@code authorNickname} 은 null 일 수 있다 — 닉네임을 정하지 않은 사용자가 있다.
 * 화면에서 대체 문구("여행자" 등)를 쓸 것.</p>
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
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    /**
     * 작성자 정보를 함께 담아 응답을 만든다.
     *
     * <p>{@code author} 가 null 이면 이름 없이 내려간다. 발자취는 사용자 삭제 시 함께
     * 지워지므로(FK {@code ON DELETE CASCADE}) 정상 경로에서는 생기지 않지만,
     * 작성자를 못 찾았다고 발자취 목록 전체가 실패하는 편이 더 나쁘다.</p>
     */
    public static FootprintResponse from(Footprint footprint, UserSummary author) {
        return new FootprintResponse(
                footprint.getId(),
                footprint.getUserId(),
                author == null ? null : author.nickname(),
                author == null ? null : author.profileImageUrl(),
                footprint.getSpotId(),
                footprint.getContent(),
                footprint.getPhotoUrl(),
                footprint.getLikeCount(),
                footprint.getCreatedAt(),
                footprint.getUpdatedAt()
        );
    }
}
