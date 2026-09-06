package com.fogapp.footprint;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fogapp.common.ForbiddenException;
import com.fogapp.common.NotFoundException;
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;
import com.fogapp.user.UserSummary;

@Service
@Transactional(readOnly = true)
public class FootprintService {

    /**
     * 반경 조회 상한(m). 이동 중 50m·스팟 안 150m 가 설계값이라 넉넉히 잡아도 이 정도면 충분하다.
     *
     * <p>상한이 없으면 {@code radius=999999} 한 번으로 전국 발자취를 긁어갈 수 있다.</p>
     */
    static final double MAX_RADIUS_METERS = 1_000;

    /**
     * 반경 조회 최대 건수.
     *
     * <p>반경이 좁아도 한 지점에 글이 몰리면 수천 건이 나올 수 있다. 지도에 그릴 수 있는 양을
     * 넘어서면 응답과 렌더가 함께 무너지므로 여기서 자른다 — 가까운 순이라 잘리는 것은 먼 것이다.</p>
     */
    static final int MAX_NEARBY = 200;

    private final FootprintRepository footprintRepository;
    private final FootprintLikeRepository footprintLikeRepository;
    private final UserRepository userRepository;

    public FootprintService(FootprintRepository footprintRepository,
                            FootprintLikeRepository footprintLikeRepository,
                            UserRepository userRepository) {
        this.footprintRepository = footprintRepository;
        this.footprintLikeRepository = footprintLikeRepository;
        this.userRepository = userRepository;
    }

    /**
     * 발자취를 남긴다. <b>남은 횟수를 하나 쓴다</b>(#116).
     *
     * <p>횟수가 없으면 429 로 막는다. 회복은 스팟 정복뿐이다 —
     * {@code VisitService.verify} 가 성공하면 기본값으로 리셋된다.</p>
     */
    @Transactional
    public Footprint create(Long userId, Long spotId, String content, String photoUrl,
                            Double lat, Double lng) {
        requireValidCoordinates(lat, lng);

        User author = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("사용자", userId));
        if (author.getFootprintQuota() <= 0) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "남은 발자취 횟수가 없습니다. 스팟을 정복하면 다시 채워집니다.");
        }
        author.consumeFootprintQuota();

        return footprintRepository.save(new Footprint(userId, spotId, content, photoUrl, lat, lng));
    }

    /**
     * 내 주변 발자취를 가까운 순으로(#115). 걷다가 지도에서 발견하는 흐름이 이걸 쓴다.
     *
     * @param radiusMeters 이동 중 50m, 해금 스팟 안에서는 150m — 앱이 정한다
     */
    public List<FootprintResponse> findNearby(Long viewerId, double lat, double lng, double radiusMeters) {
        requireValidCoordinates(lat, lng);
        if (radiusMeters <= 0 || radiusMeters > MAX_RADIUS_METERS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "radius는 0 초과 " + (long) MAX_RADIUS_METERS + "m 이하여야 합니다.");
        }

        return withAuthors(
                footprintRepository.findWithinRadius(lat, lng, radiusMeters, MAX_NEARBY), viewerId);
    }

    /**
     * 좌표를 검증한다.
     *
     * <p>범위를 벗어난 값은 PostGIS {@code geography} 캐스팅에서 예외가 되어 500 이 된다 —
     * {@code VisitService.verify} 와 같은 이유로 먼저 400 으로 거른다.</p>
     *
     * <p>⚠️ <b>"내 주변 10m" 는 여기서 검증할 수 없다.</b> 서버는 사용자의 진짜 위치를 모르고
     * 요청에 담긴 좌표가 전부다. 인증(#48)은 스팟이라는 고정 기준점이 있어 재검증되지만
     * 발자취는 기준점이 없다. 10m 는 앱이 강제하는 UX 규칙이고(#118), 좌표 위조는 막지 못한다 —
     * 횟수 제한(#116)이 피해를 제한할 뿐이다. 알고 넘어가는 한계다.</p>
     */
    private static void requireValidCoordinates(Double lat, Double lng) {
        if (lat == null && lng == null) {
            return; // 좌표 없는 글도 허용한다 — 지도에 안 뜰 뿐이다
        }
        if (lat == null || lng == null) {
            throw new IllegalArgumentException("좌표는 위도·경도를 함께 보내야 합니다.");
        }
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            throw new IllegalArgumentException("좌표 범위가 올바르지 않습니다. (lat=" + lat + ", lng=" + lng + ")");
        }
    }

    public Footprint get(Long id) {
        return footprintRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("발자취", id));
    }

    public List<Footprint> listBySpot(Long spotId) {
        return footprintRepository.findBySpotIdOrderByCreatedAtDesc(spotId);
    }

    public List<Footprint> listByUser(Long userId) {
        return footprintRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    @Transactional
    public Footprint update(Long callerId, Long id, String content, String photoUrl) {
        Footprint footprint = get(id);
        requireOwner(callerId, footprint);
        footprint.update(content, photoUrl);
        return footprint;
    }

    @Transactional
    public void delete(Long callerId, Long id) {
        Footprint footprint = get(id);
        requireOwner(callerId, footprint);
        footprintRepository.deleteById(id);
    }

    /**
     * 발자취 목록에 작성자 정보(#71)·좋아요 여부(#72)를 붙인다.
     *
     * <p>작성자·좋아요 조회는 각각 <b>목록 크기와 무관하게 한 번</b>이다. 발자취마다 읽으면
     * 20개짜리 목록에 질의가 41번(작성자 20 + 좋아요 20 + 1) 나간다.</p>
     *
     * @param viewerId 좋아요 여부를 판정할 기준 사용자. 로그인 사용자는 항상 있으므로 null이
     *                 아니지만, 비로그인 조회를 열게 되면 재사용할 수 있도록 null을 허용해 둔다.
     */
    public List<FootprintResponse> withAuthors(List<Footprint> footprints, Long viewerId) {
        if (footprints.isEmpty()) {
            // 빈 목록으로 IN () 을 만들면 SQL 이 깨진다.
            return List.of();
        }

        List<Long> authorIds = footprints.stream().map(Footprint::getUserId).distinct().toList();
        Map<Long, UserSummary> authors = userRepository.findSummariesByIdIn(authorIds).stream()
                .collect(Collectors.toMap(UserSummary::id, Function.identity()));

        Set<Long> likedFootprintIds = likedFootprintIdsAmong(viewerId, footprints);

        return footprints.stream()
                .map(f -> FootprintResponse.from(
                        f, authors.get(f.getUserId()), likedFootprintIds.contains(f.getId())))
                .toList();
    }

    /** 발자취 하나에 작성자 정보·좋아요 여부를 붙인다(#71, #72). */
    public FootprintResponse withAuthor(Footprint footprint, Long viewerId) {
        return withAuthors(List.of(footprint), viewerId).get(0);
    }

    private Set<Long> likedFootprintIdsAmong(Long viewerId, Collection<Footprint> footprints) {
        if (viewerId == null) {
            return Set.of();
        }
        return footprintLikeRepository.findLikedFootprintIds(
                viewerId, footprints.stream().map(Footprint::getId).toList());
    }

    private void requireOwner(Long callerId, Footprint footprint) {
        if (!footprint.getUserId().equals(callerId)) {
            throw new ForbiddenException("본인이 작성한 발자취만 수정·삭제할 수 있습니다.");
        }
    }
}
