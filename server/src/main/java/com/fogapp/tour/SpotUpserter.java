package com.fogapp.tour;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;

/**
 * 수집한 스팟 목록을 spots 테이블에 업서트한다(#5).
 *
 * <ul>
 *   <li>배치 내 중복(content_id)은 마지막 값으로 병합</li>
 *   <li>content_id 로 조회해 있으면 갱신, 없으면 신규 저장 → 재실행해도 중복 적재되지 않음</li>
 *   <li>content_id·title 이 비면 건너뛴다(정제)</li>
 *   <li>좌표가 완전히 같은 스팟이 이미 있으면 새로 만들지 않는다(V11 — 같은 장소의 행사·시설이
 *       따로 등록돼 마커가 포개지던 것). 기존 스팟(content_id 일치)의 갱신은 그대로다.</li>
 * </ul>
 *
 * <p>{@link SpotCollectionService}(자기호출로 트랜잭션이 안 걸리는 문제)와 분리해 별도 빈으로 두어,
 * 페이지 단위 업서트가 정상적으로 트랜잭션 경계를 갖도록 한다(갱신 시 dirty checking 필요).
 */
@Component
public class SpotUpserter {

    private final SpotRepository spotRepository;

    public SpotUpserter(SpotRepository spotRepository) {
        this.spotRepository = spotRepository;
    }

    @Transactional
    public CollectResult upsertAll(Iterable<TourSpotItem> items) {
        int skipped = 0;
        Map<String, TourSpotItem> byContentId = new LinkedHashMap<>();
        for (TourSpotItem item : items) {
            if (!StringUtils.hasText(item.contentId()) || !StringUtils.hasText(item.title())) {
                skipped++;
                continue;
            }
            byContentId.put(item.contentId(), item); // 배치 내 중복은 마지막 값으로
        }

        int created = 0;
        int updated = 0;
        for (TourSpotItem item : byContentId.values()) {
            Spot existing = spotRepository.findByContentId(item.contentId()).orElse(null);
            if (existing != null) {
                existing.updateFromCollection(
                        item.contentTypeId(), item.title(), item.addr1(), item.addr2(),
                        item.areaCode(), item.sigunguCode(), item.tel(),
                        item.firstImage(), item.firstImage2(), item.lat(), item.lng());
                updated++;
            } else if (item.lat() != null && item.lng() != null
                    && spotRepository.existsByLatAndLng(item.lat(), item.lng())) {
                // 같은 자리에 이미 스팟이 있다 — 장소가 스팟의 정체이므로 둘째는 만들지 않는다.
                skipped++;
            } else {
                spotRepository.save(new Spot(
                        item.contentId(), item.contentTypeId(), item.title(), item.addr1(), item.addr2(),
                        item.areaCode(), item.sigunguCode(), item.tel(),
                        item.firstImage(), item.firstImage2(), null, item.lat(), item.lng()));
                created++;
            }
        }
        return new CollectResult(created, updated, skipped);
    }
}
