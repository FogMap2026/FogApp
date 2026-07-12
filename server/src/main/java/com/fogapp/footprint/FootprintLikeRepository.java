package com.fogapp.footprint;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface FootprintLikeRepository extends JpaRepository<FootprintLike, Long> {

    boolean existsByFootprintIdAndUserId(Long footprintId, Long userId);

    Optional<FootprintLike> findByFootprintIdAndUserId(Long footprintId, Long userId);
}
