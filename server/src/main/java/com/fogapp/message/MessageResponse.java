package com.fogapp.message;

import java.time.OffsetDateTime;

/**
 * 메시지 응답. {@code mine} 은 서버가 조회자 기준으로 미리 계산한다 — 앱이 말풍선을 좌우로
 * 가르려고 내 사용자 id 를 따로 알 필요가 없게({@code MatchResponse.direction} 과 같은 이유).
 */
public record MessageResponse(
        Long id,
        Long matchId,
        boolean mine,
        String content,
        OffsetDateTime createdAt
) {
    public static MessageResponse from(Message message, Long viewerId) {
        return new MessageResponse(
                message.getId(),
                message.getMatchId(),
                message.getSenderId().equals(viewerId),
                message.getContent(),
                message.getCreatedAt()
        );
    }
}
