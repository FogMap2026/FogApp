package com.fogapp.tour;

/** 수집 배치 결과 요약(#5). */
public record CollectResult(int created, int updated, int skipped) {

    public static CollectResult empty() {
        return new CollectResult(0, 0, 0);
    }

    public CollectResult plus(CollectResult other) {
        return new CollectResult(
                created + other.created,
                updated + other.updated,
                skipped + other.skipped);
    }

    public int total() {
        return created + updated;
    }
}
