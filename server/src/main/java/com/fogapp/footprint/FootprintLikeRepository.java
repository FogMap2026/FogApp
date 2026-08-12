package com.fogapp.footprint;

import java.util.Collection;
import java.util.Optional;
import java.util.Set;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FootprintLikeRepository extends JpaRepository<FootprintLike, Long> {

    boolean existsByFootprintIdAndUserId(Long footprintId, Long userId);

    Optional<FootprintLike> findByFootprintIdAndUserId(Long footprintId, Long userId);

    /**
     * 주어진 발자취들 중 이 사용자가 좋아요를 누른 것의 id(#72 {@code likedByMe} 판정).
     *
     * <p>발자취 하나하나 {@code existsByFootprintIdAndUserId}를 부르면 목록 조회 한 번에
     * N번 질의하게 된다 — {@link com.fogapp.user.UserRepository#findSummariesByIdIn}과
     * 같은 이유로 배치 조회한다.</p>
     */
    @Query("SELECT fl.footprintId FROM FootprintLike fl WHERE fl.userId = :userId AND fl.footprintId IN :footprintIds")
    Set<Long> findLikedFootprintIds(@Param("userId") Long userId, @Param("footprintIds") Collection<Long> footprintIds);
}
