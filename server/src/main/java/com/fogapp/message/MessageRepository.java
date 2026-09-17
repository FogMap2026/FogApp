package com.fogapp.message;

import java.util.List;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MessageRepository extends JpaRepository<Message, Long> {

    /** 대화방을 처음 열 때 — 최근 것부터 {@code pageable} 만큼. 호출부가 시간순으로 뒤집는다. */
    @Query("SELECT m FROM Message m WHERE m.matchId = :matchId ORDER BY m.id DESC")
    List<Message> findLatest(@Param("matchId") Long matchId, Pageable pageable);

    /** 열려 있는 대화방의 주기 갱신 — 마지막으로 받은 id 이후만. */
    @Query("SELECT m FROM Message m WHERE m.matchId = :matchId AND m.id > :afterId ORDER BY m.id ASC")
    List<Message> findAfter(@Param("matchId") Long matchId, @Param("afterId") Long afterId, Pageable pageable);
}
