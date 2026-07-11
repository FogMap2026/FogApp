package com.fogapp.spot;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * 스팟 조회(#7). 지도가 지역별/반경별로 스팟을 로드한다. 페이지 크기·반경 상한을 강제한다.
 */
@Service
@Transactional(readOnly = true)
public class SpotQueryService {

    static final int MAX_PAGE_SIZE = 200;
    static final double MAX_RADIUS_METERS = 20_000;

    private final SpotRepository spotRepository;

    public SpotQueryService(SpotRepository spotRepository) {
        this.spotRepository = spotRepository;
    }

    /** 지역 코드별 스팟(페이징). size 는 최대 {@value #MAX_PAGE_SIZE} 로 제한한다. */
    public PageResponse<SpotResponse> findByRegion(String areaCode, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        Page<Spot> result = spotRepository.findByAreaCode(areaCode, PageRequest.of(safePage, safeSize));
        return PageResponse.from(result, SpotResponse::from);
    }

    /** 현재 위치 반경(m) 내 스팟(가까운 순). 반경은 최대 {@value #MAX_RADIUS_METERS}m. */
    public List<SpotResponse> findNearby(double lat, double lng, double radiusMeters) {
        if (radiusMeters <= 0 || radiusMeters > MAX_RADIUS_METERS) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "radius는 0 초과 " + (long) MAX_RADIUS_METERS + "m 이하여야 합니다.");
        }
        return spotRepository.findWithinRadius(lat, lng, radiusMeters).stream()
                .map(SpotResponse::from)
                .toList();
    }
}
