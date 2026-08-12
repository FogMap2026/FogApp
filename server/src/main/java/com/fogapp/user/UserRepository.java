package com.fogapp.user;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByFirebaseUid(String firebaseUid);

    /**
     * 여러 사용자의 공개 정보를 한 번에 조회한다(#71).
     *
     * <p>발자취 목록처럼 작성자를 함께 보여줘야 하는 응답이 쓴다. 행마다 사용자를 조회하면
     * 발자취 20개에 질의가 21번 나간다({@code N+1}). 목록을 받은 뒤 id 를 모아 여기서 한 번에 읽는다.</p>
     *
     * <p>엔티티가 아니라 {@link UserSummary} 로 받는다 — 필요한 컬럼만 읽고, 이메일 같은
     * 비공개 필드가 실수로 응답에 실릴 여지를 없앤다.</p>
     */
    @Query("SELECT new com.fogapp.user.UserSummary(u.id, u.nickname, u.profileImageUrl) "
            + "FROM User u WHERE u.id IN :ids")
    List<UserSummary> findSummariesByIdIn(@Param("ids") Collection<Long> ids);
}
