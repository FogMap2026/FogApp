package com.fogapp.journey;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 걸어온 자리의 저장·조회(#131). */
@Service
public class JourneyService {

    /**
     * 한 번에 돌려주는 궤적의 최대 개수.
     *
     * <p>15m 마다 한 점이므로 5,000 점이면 <b>약 75km</b> — 앱이 안개 구멍을 복원하는 데
     * 충분하고, 그 이상은 화면에 의미 있는 차이를 만들지 않으면서 `setHoles` 비용만 는다.</p>
     */
    public static final int MAX_POINTS_RETURNED = 5_000;

    private final JourneyPointRepository repository;

    public JourneyService(JourneyPointRepository repository) {
        this.repository = repository;
    }

    /**
     * 궤적을 저장한다. <b>이미 있는 점은 건너뛴다</b> — 재전송이 안전하다.
     *
     * <p>좌표 범위를 벗어난 점은 <b>거르되 나머지는 살린다.</b> GPS 가 한 번 튀었다고
     * 그 묶음 전체를 버리면 걸어온 자리가 통째로 사라진다 — 400 으로 되돌려주면 앱은
     * 같은 묶음을 계속 재전송하다 영영 못 올린다.</p>
     *
     * @return 실제로 새로 저장된 점의 수
     */
    @Transactional
    public int record(Long userId, List<JourneyPointRequest> points) {
        int saved = 0;
        for (JourneyPointRequest p : points) {
            if (isOutOfRange(p)) {
                continue;
            }
            saved += repository.insertIgnoringDuplicate(userId, p.lat(), p.lng(), p.recordedAt());
        }
        return saved;
    }

    private boolean isOutOfRange(JourneyPointRequest p) {
        return p.lat() < -90 || p.lat() > 90 || p.lng() < -180 || p.lng() > 180;
    }

    @Transactional(readOnly = true)
    public List<JourneyPointResponse> mine(Long userId, OffsetDateTime from, OffsetDateTime to) {
        return repository.findMine(userId, from, to, MAX_POINTS_RETURNED)
                .stream()
                .map(JourneyPointResponse::from)
                .toList();
    }
}
