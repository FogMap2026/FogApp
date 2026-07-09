package com.fogapp.footprint;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface FootprintRepository extends JpaRepository<Footprint, Long> {

    List<Footprint> findBySpotIdOrderByCreatedAtDesc(Long spotId);

    List<Footprint> findByUserIdOrderByCreatedAtDesc(Long userId);
}
