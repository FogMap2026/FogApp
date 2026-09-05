package com.fogapp.tour;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;

/**
 * 소개글 수집의 <b>대상 선정</b>을 고정한다(#100 후속).
 *
 * <p>여기가 깨지면 증상이 조용하다 — 로그는 "대상 200, 채움 0" 만 반복하고, 그게
 * "다 채워졌다" 인지 "같은 스팟만 계속 집어간다" 인지 구분되지 않는다. 실제로 관광공사에
 * 소개글이 없는 스팟(호텔·숙박, 끝난 축제)이 존재해 이 구분이 필요하다.</p>
 */
class SpotOverviewCollectorTest {

    private TourApiClient tourApiClient;
    private SpotRepository spotRepository;
    private SpotOverviewWriter overviewWriter;
    private SpotOverviewCollector sut;

    @BeforeEach
    void setUp() {
        tourApiClient = mock(TourApiClient.class);
        spotRepository = mock(SpotRepository.class);
        overviewWriter = mock(SpotOverviewWriter.class);
        sut = new SpotOverviewCollector(tourApiClient, spotRepository, overviewWriter);
    }

    /**
     * ⚠️ 이 헬퍼는 {@code when(...)} 인자 안에서 부르면 안 된다. 안에서 다시 스터빙을 하므로
     * 바깥 스터빙이 진행 중이면 Mockito 가 {@code UnfinishedStubbingException} 을 던진다.
     * 반드시 먼저 만들어 변수에 담은 뒤 스터빙에 넘길 것.
     */
    private Spot spot(long id, String contentId) {
        Spot spot = mock(Spot.class);
        when(spot.getId()).thenReturn(id);
        when(spot.getContentId()).thenReturn(contentId);
        return spot;
    }

    @Test
    void 소개글이_있으면_저장한다() {
        Spot target = spot(1L, "126508");
        when(spotRepository.findWithoutOverview(anyInt())).thenReturn(List.of(target));
        when(tourApiClient.fetchOverview("126508")).thenReturn("불국사는 ...");

        assertThat(sut.fillMissing(200)).isEqualTo(1);
        verify(overviewWriter).save(1L, "불국사는 ...");
    }

    @Test
    void 소개글이_없으면_빈_문자열로_기록해_다음_실행에서_제외되게_한다() {
        // 핵심. NULL 로 두면 매 실행 같은 스팟을 다시 집어가 호출만 태우고,
        // 그런 스팟이 쌓이면 창을 가득 채워 배치가 조용히 멈춘다.
        Spot target = spot(2L, "3465927");
        when(spotRepository.findWithoutOverview(anyInt())).thenReturn(List.of(target));
        when(tourApiClient.fetchOverview("3465927")).thenReturn(null);

        assertThat(sut.fillMissing(200)).isZero();   // 채운 건 아니다
        verify(overviewWriter).save(2L, "");         // 그래도 "조회했다" 는 남긴다
    }

    @Test
    void 빈_문자열_응답도_소개글_없음으로_본다() {
        // 관광공사는 항목은 주면서 overview 만 "" 로 주는 경우가 있다(호텔·숙박).
        Spot target = spot(3L, "3465024");
        when(spotRepository.findWithoutOverview(anyInt())).thenReturn(List.of(target));
        when(tourApiClient.fetchOverview("3465024")).thenReturn("   ");

        assertThat(sut.fillMissing(200)).isZero();
        verify(overviewWriter).save(3L, "");
    }

    @Test
    void 조회에_실패하면_기록하지_않는다_다음_실행이_재시도한다() {
        // 실패는 "소개글이 없다" 와 다르다 — NULL 로 남겨 다시 집어가게 해야 한다.
        Spot target = spot(4L, "999");
        when(spotRepository.findWithoutOverview(anyInt())).thenReturn(List.of(target));
        when(tourApiClient.fetchOverview("999")).thenThrow(new IllegalStateException("일시 오류"));

        assertThat(sut.fillMissing(200)).isZero();
        verify(overviewWriter, never()).save(eq(4L), anyString());
    }

    @Test
    void 일일_한도를_소진하면_남은_스팟을_건드리지_않고_멈춘다() {
        Spot first = spot(5L, "aaa");
        Spot second = spot(6L, "bbb");
        when(spotRepository.findWithoutOverview(anyInt())).thenReturn(List.of(first, second));
        when(tourApiClient.fetchOverview("aaa"))
                .thenThrow(new TourApiQuotaExceededException("한도 소진"));

        assertThat(sut.fillMissing(200)).isZero();
        verify(tourApiClient, never()).fetchOverview("bbb");
    }

    @Test
    void 대상이_없으면_아무것도_호출하지_않는다() {
        when(spotRepository.findWithoutOverview(anyInt())).thenReturn(List.of());

        assertThat(sut.fillMissing(200)).isZero();
        verify(tourApiClient, never()).fetchOverview(anyString());
    }
}
