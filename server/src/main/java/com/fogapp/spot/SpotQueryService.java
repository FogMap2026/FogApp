package com.fogapp.spot;

import java.util.Collection;
import java.util.List;
import java.util.Set;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fogapp.visit.VisitRepository;

/**
 * 스팟 조회(#7, #50). 지도가 지역별/반경별로 스팟을 로드한다. 페이지 크기·반경 상한을 강제한다.
 *
 * <p>모든 조회는 <b>요청한 사용자</b>를 받는다 — 해금 여부가 사용자마다 다르기 때문이다.
 * 사용자는 인증 필터가 세운 값이어야 하며 요청 파라미터로 받지 않는다.</p>
 */
@Service
@Transactional(readOnly = true)
public class SpotQueryService {

    static final int MAX_PAGE_SIZE = 200;
    static final double MAX_RADIUS_METERS = 20_000;

    private final SpotRepository spotRepository;
    private final VisitRepository visitRepository;

    public SpotQueryService(SpotRepository spotRepository, VisitRepository visitRepository) {
        this.spotRepository = spotRepository;
        this.visitRepository = visitRepository;
    }

    /** 지역 코드별 스팟(페이징). size 는 최대 {@value #MAX_PAGE_SIZE} 로 제한한다. */
    public PageResponse<SpotResponse> findByRegion(Long userId, String areaCode, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        Page<Spot> result = spotRepository.findByAreaCode(areaCode, PageRequest.of(safePage, safeSize));

        Set<Long> unlocked = unlockedIdsAmong(userId, result.getContent());
        return PageResponse.from(result, spot -> SpotResponse.from(spot, unlocked.contains(spot.getId())));
    }

    /** 현재 위치 반경(m) 내 스팟(가까운 순). 반경은 최대 {@value #MAX_RADIUS_METERS}m. */
    public List<SpotResponse> findNearby(Long userId, double lat, double lng, double radiusMeters) {
        if (radiusMeters <= 0 || radiusMeters > MAX_RADIUS_METERS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "radius는 0 초과 " + (long) MAX_RADIUS_METERS + "m 이하여야 합니다.");
        }

        List<Spot> spots = spotRepository.findWithinRadius(lat, lng, radiusMeters);
        Set<Long> unlocked = unlockedIdsAmong(userId, spots);
        return spots.stream()
                .map(spot -> SpotResponse.from(spot, unlocked.contains(spot.getId())))
                .toList();
    }

    /**
     * 조회 결과 중 이 사용자가 인증해 해금된 스팟 id 를 한 번의 질의로 모은다.
     *
     * <p>결과가 비었으면 질의하지 않는다 — 빈 목록으로 {@code IN ()} 을 만들면 SQL 이 깨진다.</p>
     */
    private Set<Long> unlockedIdsAmong(Long userId, Collection<Spot> spots) {
        if (userId == null || spots.isEmpty()) {
            return Set.of();
        }
        return visitRepository.findVisitedSpotIds(userId, spots.stream().map(Spot::getId).toList());
    }
}
