package com.fogapp.tour;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.spot.SpotRepository;

/**
 * 소개글을 한 건씩 커밋한다(#100).
 *
 * <p>{@link SpotOverviewCollector} 안에 두면 <b>자기호출이라 트랜잭션이 걸리지 않아</b>
 * dirty checking 으로 갱신되지 않는다 — {@link SpotUpserter} 를
 * {@link SpotCollectionService} 에서 분리한 것과 같은 이유다.</p>
 *
 * <p>건별 커밋인 이유: 수백 건을 한 트랜잭션에 묶으면 마지막에 터졌을 때 그때까지 쓴
 * API 호출을 전부 낭비한다. 상세는 스팟 1건당 1회라 재호출 비용이 크다.</p>
 */
@Component
public class SpotOverviewWriter {

    private final SpotRepository spotRepository;

    public SpotOverviewWriter(SpotRepository spotRepository) {
        this.spotRepository = spotRepository;
    }

    @Transactional
    public void save(Long spotId, String overview) {
        spotRepository.findById(spotId).ifPresent(spot -> spot.updateOverview(overview));
    }
}
