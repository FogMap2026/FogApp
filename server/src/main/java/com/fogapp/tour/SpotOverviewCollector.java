package com.fogapp.tour;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;

/**
 * 소개글이 비어 있는 스팟에 공통정보 조회로 {@code overview} 를 채운다(#100).
 *
 * <p><b>왜 별도 단계인가.</b> 목록 수집이 쓰는 {@code areaBasedList} 는 소개글을 주지 않는다.
 * 그런데 소개글은 방문 인증으로 스팟이 해금됐을 때 보여주는 <b>탐험의 보상</b>이다(3-6).
 * 이 단계가 없으면 해금해도 빈 화면이 열린다.</p>
 *
 * <p><b>호출량.</b> 상세는 스팟 1건당 1회다 — 목록 1,000건이면 상세도 1,000회라서 목록 수집과
 * 비용이 다르다. 그래서 두 가지로 막는다.</p>
 *
 * <ul>
 *   <li>이미 소개글이 있는 스팟은 조회하지 않는다 — 재실행해도 남은 것만 채운다</li>
 *   <li>한 번 실행에 {@code maxPerRun} 건까지만 — 여러 번 나눠 돌리면 결국 다 채워진다</li>
 * </ul>
 */
@Service
public class SpotOverviewCollector {

    private static final Logger log = LoggerFactory.getLogger(SpotOverviewCollector.class);

    private final TourApiClient tourApiClient;
    private final SpotRepository spotRepository;
    private final SpotOverviewWriter overviewWriter;

    public SpotOverviewCollector(TourApiClient tourApiClient,
                                 SpotRepository spotRepository,
                                 SpotOverviewWriter overviewWriter) {
        this.tourApiClient = tourApiClient;
        this.spotRepository = spotRepository;
        this.overviewWriter = overviewWriter;
    }

    /**
     * 소개글이 없는 스팟을 최대 {@code maxPerRun} 건까지 채운다.
     *
     * @return 실제로 채운 건수
     */
    public int fillMissing(int maxPerRun) {
        if (maxPerRun <= 0) {
            return 0;
        }

        List<Spot> targets = spotRepository.findWithoutOverview(maxPerRun);
        if (targets.isEmpty()) {
            log.info("소개글을 채울 스팟이 없습니다.");
            return 0;
        }

        int filled = 0;
        int failed = 0;
        for (Spot spot : targets) {
            try {
                String overview = tourApiClient.fetchOverview(spot.getContentId());
                if (StringUtils.hasText(overview)) {
                    overviewWriter.save(spot.getId(), overview);
                    filled++;
                }
            } catch (Exception e) {
                // 한 건이 실패했다고 나머지를 포기하지 않는다. 다음 실행이 이 스팟을 다시 집어간다
                // (여전히 overview 가 비어 있으므로).
                failed++;
                log.warn("스팟 {}(content_id={}) 소개글 조회 실패: {}",
                        spot.getId(), spot.getContentId(), e.toString());
            }
        }

        log.info("소개글 수집: 대상 {}, 채움 {}, 실패 {}", targets.size(), filled, failed);
        return filled;
    }

}
