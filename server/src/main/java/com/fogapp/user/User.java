package com.fogapp.user;

import java.time.OffsetDateTime;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 사용자(#1 users 테이블). Firebase UID로 식별하며 최초 로그인 시 업서트된다(#4).
 *
 * <p>성향 컬럼(personality_type / personality_scores)은 2-6(#31)에서 채점된 결과를
 * #32에서 저장한다. personality_scores는 JSONB — 직렬화된 JSON 문자열을 그대로 저장/반환한다.
 */
@Entity
@Table(name = "users")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User {

    /**
     * 발자취 작성 횟수 기본값이자 <b>정복 시 회복되는 값</b>(#116).
     *
     * <p>⚠️ <b>누적이 아니라 리셋이다.</b> {@code +3} 으로 쌓으면 정복만 반복해 잔량을
     * 모아두었다가 한 지점에 몰아쓸 수 있어, 막으려던 도배가 그대로 돌아온다.</p>
     */
    public static final int DEFAULT_FOOTPRINT_QUOTA = 3;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "firebase_uid", nullable = false, unique = true)
    private String firebaseUid;

    private String email;

    private String nickname;

    @Column(name = "profile_image_url")
    private String profileImageUrl;

    @Column(name = "personality_type")
    private String personalityType;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "personality_scores")
    private String personalityScores;

    /**
     * 남은 발자취 작성 횟수(#116).
     *
     * <p>글을 남기는 권리를 <b>탐험으로 벌게</b> 만드는 값이다 — 작성하면 줄고,
     * 스팟을 정복하면 기본값으로 리셋된다.</p>
     */
    @Column(name = "footprint_quota", nullable = false)
    private int footprintQuota = DEFAULT_FOOTPRINT_QUOTA;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public User(String firebaseUid, String email, String nickname, String profileImageUrl) {
        this.firebaseUid = firebaseUid;
        this.email = email;
        this.nickname = nickname;
        this.profileImageUrl = profileImageUrl;
    }

    /** 프로필 수정. null 인 필드는 변경하지 않는다(부분 수정). */
    public void updateProfile(String nickname, String profileImageUrl) {
        if (nickname != null) {
            this.nickname = nickname;
        }
        if (profileImageUrl != null) {
            this.profileImageUrl = profileImageUrl;
        }
    }

    /** 성향 테스트 결과 저장(#31 채점 결과). 재응시 시 이전 결과를 덮어쓴다. */
    public void updatePersonality(String personalityType, String personalityScoresJson) {
        this.personalityType = personalityType;
        this.personalityScores = personalityScoresJson;
    }

    /**
     * 발자취를 하나 남겼다(#116).
     *
     * @throws IllegalStateException 남은 횟수가 없을 때
     */
    public void consumeFootprintQuota() {
        if (footprintQuota <= 0) {
            throw new IllegalStateException("남은 발자취 횟수가 없습니다.");
        }
        footprintQuota--;
    }

    /** 스팟을 정복해 횟수를 회복한다(#116). 누적이 아니라 기본값으로 되돌린다. */
    public void resetFootprintQuota() {
        this.footprintQuota = DEFAULT_FOOTPRINT_QUOTA;
    }
}
