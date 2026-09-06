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
 *   <li>이미 <b>조회한</b> 스팟은 다시 부르지 않는다 — 재실행해도 남은 것만 채운다</li>
 *   <li>한 번 실행에 {@code maxPerRun} 건까지만 — 여러 번 나눠 돌리면 결국 다 채워진다</li>
 * </ul>
 *
 * <p><b>"조회했다"의 표식은 빈 문자열이다.</b> 관광공사에 소개글이 없는 스팟이 실제로 있어
 * (호텔·숙박이 대표적이고, 끝난 축제처럼 항목 자체가 사라지기도 한다) 그런 스팟을 NULL 로
 * 두면 매 실행 대상에 다시 들어와 채워지지도 않으면서 호출만 태운다. 쌓이면 결국 창을
 * 가득 채워 <b>배치가 조용히 멈춘다.</b></p>
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
        int noData = 0;
        int failed = 0;
        boolean quotaExceeded = false;
        for (Spot spot : targets) {
            try {
                String overview = tourApiClient.fetchOverview(spot.getContentId());
                if (StringUtils.hasText(overview)) {
                    overviewWriter.save(spot.getId(), overview);
                    filled++;
                } else {
                    // 관광공사에 소개글이 없는 스팟이 실제로 있다 — 호텔·숙박(contentTypeId 32)이
                    // 대표적이고, 끝난 축제처럼 항목 자체가 사라진 경우도 있다.
                    //
                    // 빈 문자열로 기록해 "조회했고 없더라"를 남긴다. NULL 로 두면 다음 실행이
                    // 같은 스팟을 다시 집어가 채워지지도 않으면서 호출만 태우고, 그런 스팟이
                    // 쌓이면 결국 창을 가득 채워 배치가 조용히 멈춘다.
                    overviewWriter.save(spot.getId(), "");
                    noData++;
                }
            } catch (TourApiQuotaExceededException e) {
                // 한도 소진은 그 건만의 문제가 아니다 — 남은 건도 전부 실패한다.
                // 계속 두드려도 채워지는 건 없고 경고만 수백 줄 쌓이므로 즉시 멈춘다.
                // 한도는 매일 초기화되니 나머지는 다음 날 실행이 이어서 채운다.
                quotaExceeded = true;
                break;
            } catch (Exception e) {
                // 한 건이 실패했다고 나머지를 포기하지 않는다. 실패한 스팟은 overview 가
                // NULL 로 남으므로 다음 실행이 다시 집어간다 — 재시도가 의도인 경우다.
                // (소개글이 원래 없는 경우와 달리 여기서는 빈 문자열을 쓰지 않는다.)
                failed++;
                log.warn("스팟 {}(content_id={}) 소개글 조회 실패: {}",
                        spot.getId(), spot.getContentId(), e.toString());
            }
        }

        log.info("소개글 수집: 대상 {}, 채움 {}, 소개글없음 {}, 실패 {}",
                targets.size(), filled, noData, failed);
        if (quotaExceeded) {
            log.warn("관광공사 API 일일 호출 한도를 소진해 {}건을 남기고 중단했습니다. "
                    + "한도는 매일 초기화되므로 내일 다시 실행하면 이어서 채웁니다.",
                    targets.size() - filled - failed);
        }
        return filled;
    }

}
