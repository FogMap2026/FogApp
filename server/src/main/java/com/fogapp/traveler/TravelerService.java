package com.fogapp.traveler;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;

/** 주변 여행자 익명 표시(#133, 6-3) — 게시·중지·조회. */
@Service
@Transactional(readOnly = true)
public class TravelerService {

    /**
     * "가장 가까운 스팟"을 찾을 때 뒤지는 반경. 방문 인증(100m)보다 훨씬 넓다 —
     * 이건 인증이 아니라 "어디 근처인지"를 맥락으로 전달하는 것이라, 스팟이
     * 드문 지역에서도 근처 스팟 하나는 잡혀야 한다.
     */
    private static final double NEAREST_SPOT_SEARCH_RADIUS_METERS = 3_000;

    /**
     * 신고 접수본: "측정 시점으로부터 30분이 경과한 위치정보만 지연하여 제공".
     * 최근 30분 이내 갱신은 조회에서 뺀다 — 실시간이 아니라는 것을 저장이 아니라
     * <b>조회 시점</b>에서 강제한다.
     */
    private static final int DELAY_MINUTES = 30;

    private final TravelerPositionRepository repository;
    private final SpotRepository spotRepository;

    public TravelerService(TravelerPositionRepository repository, SpotRepository spotRepository) {
        this.repository = repository;
        this.spotRepository = spotRepository;
    }

    /**
     * 위치를 게시한다(opt-in). 좌표를 가장 가까운 스팟 id 로 환산해 <b>그것만</b>
     * 저장한다 — 좌표 자체는 이 메서드를 벗어나면 남지 않는다.
     *
     * @throws ResponseStatusException 주변에 스팟이 하나도 없으면 404. 표시할
     *                                  스팟이 없는 곳에서는 공유할 것도 없다.
     */
    @Transactional
    public void share(Long userId, double lat, double lng) {
        List<Spot> nearby = spotRepository.findWithinRadius(lat, lng, NEAREST_SPOT_SEARCH_RADIUS_METERS);
        if (nearby.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "주변에 표시할 스팟이 없습니다.");
        }
        Spot nearest = nearby.get(0); // findWithinRadius는 가까운 순으로 정렬돼 있다.
        repository.upsert(userId, nearest.getId());
    }

    /** 공유를 끈다. 신고 접수본의 "갱신 시 삭제 또는 덮어쓰기" 중 삭제 쪽 — 사용자가 직접 끄는 경로. */
    @Transactional
    public void stopSharing(Long userId) {
        repository.deleteByUserId(userId);
    }

    /** 반경 내 익명 여행자 목록. 본인과 30분 이내 갱신분은 제외된다. */
    public List<NearbyTravelerResponse> nearby(Long userId, double lat, double lng, double radiusMeters) {
        OffsetDateTime cutoff = OffsetDateTime.now().minusMinutes(DELAY_MINUTES);
        return repository.findNearby(userId, lat, lng, radiusMeters, cutoff)
                .stream()
                .map(NearbyTravelerResponse::from)
                .toList();
    }
}
