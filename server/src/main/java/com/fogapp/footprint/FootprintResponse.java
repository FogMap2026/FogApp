package com.fogapp.footprint;

import java.time.OffsetDateTime;

import com.fogapp.user.UserSummary;

/**
 * 발자취 응답(#23, #71, #72).
 *
 * <p>작성자의 닉네임·프로필 이미지를 함께 담는다. 카드에 "누가 썼는지"를 보여줘야 하는데
 * {@code userId} 만으로는 앱이 사용자마다 프로필을 따로 조회하게 되고(N+1), 애초에
 * {@code GET /api/profile} 은 <b>본인 것만</b> 내려주므로 남의 프로필을 볼 방법이 없다.</p>
 *
 * <p>{@code authorNickname} 은 null 일 수 있다 — 닉네임을 정하지 않은 사용자가 있다.
 * 화면에서 대체 문구("여행자" 등)를 쓸 것.</p>
 *
 * <p>{@code likedByMe} 는 <b>조회한 사용자 기준</b>이다(#72) — 같은 발자취라도 보는 사람마다
 * 다르다. 좋아요 버튼을 채운 하트로 보여줄지 빈 하트로 보여줄지는 이 값으로 정한다.</p>
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
     * 작성자 정보·좋아요 여부를 함께 담아 응답을 만든다.
     *
     * <p>{@code author} 가 null 이면 이름 없이 내려간다. 발자취는 사용자 삭제 시 함께
     * 지워지므로(FK {@code ON DELETE CASCADE}) 정상 경로에서는 생기지 않지만,
     * 작성자를 못 찾았다고 발자취 목록 전체가 실패하는 편이 더 나쁘다.</p>
     *
     * <p>{@code author}·{@code likedByMe} 둘 다 필수로 받는다 — 기본값 오버로드를 두면
     * 호출부가 채우는 걸 잊어도 컴파일이 통과해, 카드에 작성자가 안 보이거나 좋아요가
     * 항상 빈 채로 나가는 게 조용히 방치된다.</p>
     */
    public static FootprintResponse from(Footprint footprint, UserSummary author, boolean likedByMe) {
        return new FootprintResponse(
                footprint.getId(),
                footprint.getUserId(),
                author == null ? null : author.nickname(),
                author == null ? null : author.profileImageUrl(),
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
