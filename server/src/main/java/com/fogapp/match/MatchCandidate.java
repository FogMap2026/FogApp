package com.fogapp.match;

/** 매칭 후보(#37). similarity는 0~1(1에 가까울수록 성향이 비슷함). */
public record MatchCandidate(Long userId, String nickname, double similarity) {
}
