package com.fogapp.match;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MatchRepository extends JpaRepository<Match, Long> {

    boolean existsByRequesterIdAndAddresseeId(Long requesterId, Long addresseeId);

    @Query("SELECT m FROM Match m WHERE m.requesterId = :userId OR m.addresseeId = :userId ORDER BY m.createdAt DESC")
    List<Match> findAllInvolvingUser(@Param("userId") Long userId);
}
