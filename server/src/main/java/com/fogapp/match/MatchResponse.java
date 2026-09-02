package com.fogapp.match;

import java.time.OffsetDateTime;

import com.fogapp.user.UserSummary;

/**
 * 매칭 응답(#1-8, 5-2).
 *
 * <p>{@code requesterId}/{@code addresseeId}만으로는 앱이 "누가 보냈는지"를 보려면
 * 로그인 사용자 id와 매번 비교해야 한다. 서버가 이미 요청자(viewer)를 알고 있으므로
 * {@code direction}("SENT"/"RECEIVED")과 상대방 정보를 미리 계산해 내려준다.</p>
 *
 * <p>{@code counterpartNickname}은 null일 수 있다(#71과 같은 이유 — 닉네임 미설정).</p>
 */
public record MatchResponse(
        Long id,
        Long requesterId,
        Long addresseeId,
        String status,
        Double score,
        String direction,
        Long counterpartId,
        String counterpartNickname,
        String counterpartProfileImageUrl,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    /**
     * @param viewerId   응답을 보는 사용자. requester와 addressee 중 어느 쪽이 "나"인지로
     *                   direction·counterpart를 정한다.
     * @param counterpart null이면 상대방 정보 없이 내려간다(정상 경로에서는 생기지 않음 —
     *                    사용자 삭제는 매칭도 함께 지운다).
     */
    public static MatchResponse from(Match match, Long viewerId, UserSummary counterpart) {
        boolean sentByViewer = match.getRequesterId().equals(viewerId);
        Long counterpartId = sentByViewer ? match.getAddresseeId() : match.getRequesterId();
        return new MatchResponse(
                match.getId(),
                match.getRequesterId(),
                match.getAddresseeId(),
                match.getStatus(),
                match.getScore(),
                sentByViewer ? "SENT" : "RECEIVED",
                counterpartId,
                counterpart == null ? null : counterpart.nickname(),
                counterpart == null ? null : counterpart.profileImageUrl(),
                match.getCreatedAt(),
                match.getUpdatedAt()
        );
    }
}
