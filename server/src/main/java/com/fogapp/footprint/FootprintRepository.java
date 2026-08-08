package com.fogapp.footprint;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FootprintRepository extends JpaRepository<Footprint, Long> {

    List<Footprint> findBySpotIdOrderByCreatedAtDesc(Long spotId);

    List<Footprint> findByUserIdOrderByCreatedAtDesc(Long userId);

    /**
     * like_count를 원자적으로 증감한다(동시 좋아요 경합 방지를 위해 read-modify-write 대신 UPDATE 쿼리 사용).
     * 0 미만으로 내려가지 않도록 감소는 like_count > 0 조건을 건다.
     */
    @Modifying
    @Query("UPDATE Footprint f SET f.likeCount = f.likeCount + 1 WHERE f.id = :id")
    void incrementLikeCount(@Param("id") Long id);

    @Modifying
    @Query("UPDATE Footprint f SET f.likeCount = f.likeCount - 1 WHERE f.id = :id AND f.likeCount > 0")
    void decrementLikeCount(@Param("id") Long id);
}
