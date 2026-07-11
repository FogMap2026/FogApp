package com.fogapp.tour;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * 지역기반 스팟 수집 오케스트레이션(#5): 페이지를 넘겨 가며 수집 → 업서트.
 * 실제 트랜잭션 경계·적재는 {@link SpotUpserter}가 담당한다.
 */
@Service
public class SpotCollectionService {

    private static final Logger log = LoggerFactory.getLogger(SpotCollectionService.class);

    private final TourApiClient tourApiClient;
    private final SpotUpserter spotUpserter;

    public SpotCollectionService(TourApiClient tourApiClient, SpotUpserter spotUpserter) {
        this.tourApiClient = tourApiClient;
        this.spotUpserter = spotUpserter;
    }

    /** 지역 하나를 최대 maxPages 까지 수집한다. 빈 페이지를 만나면 조기 종료. */
    public CollectResult collectArea(String areaCode, int maxPages, int numOfRows) {
        CollectResult total = CollectResult.empty();
        for (int pageNo = 1; pageNo <= maxPages; pageNo++) {
            List<TourSpotItem> items = tourApiClient.fetchAreaBased(areaCode, pageNo, numOfRows);
            if (items.isEmpty()) {
                break;
            }
            total = total.plus(spotUpserter.upsertAll(items));
        }
        log.info("지역 {} 수집 완료: 신규 {}, 갱신 {}, 스킵 {}",
                areaCode, total.created(), total.updated(), total.skipped());
        return total;
    }

    /** 여러 지역을 순차 수집한다. */
    public CollectResult collectAreas(List<String> areaCodes, int maxPages, int numOfRows) {
        CollectResult total = CollectResult.empty();
        for (String areaCode : areaCodes) {
            total = total.plus(collectArea(areaCode, maxPages, numOfRows));
        }
        log.info("전체 수집 완료: 신규 {}, 갱신 {}, 스킵 {}",
                total.created(), total.updated(), total.skipped());
        return total;
    }
}
