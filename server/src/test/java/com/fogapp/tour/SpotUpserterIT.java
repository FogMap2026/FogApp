package com.fogapp.tour;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;

/**
 * 스팟 업서트(#5) 정제·중복제거·재실행 무결성·geom 자동채움을 실제 PostGIS로 검증한다.
 */
@Testcontainers
@SpringBootTest
class SpotUpserterIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private SpotUpserter upserter;

    @Autowired
    private SpotRepository spotRepository;

    private static TourSpotItem item(String contentId, String title, Double lat, Double lng) {
        return new TourSpotItem(contentId, "12", title, "주소", null, "1", "1", null, null, null, lat, lng);
    }

    @Test
    void 신규_스팟이_저장되고_geom이_자동으로_채워진다() {
        CollectResult result = upserter.upsertAll(List.of(item("UP-1", "불국사", 35.7900, 129.3320)));

        assertThat(result.created()).isEqualTo(1);
        Spot saved = spotRepository.findByContentId("UP-1").orElseThrow();
        assertThat(saved.getGeom()).isNotNull();
        assertThat(saved.getGeom().getX()).isEqualTo(129.3320);
        assertThat(saved.getGeom().getY()).isEqualTo(35.7900);
    }

    @Test
    void 같은_content_id를_재실행하면_중복없이_갱신되고_geom도_갱신된다() {
        upserter.upsertAll(List.of(item("UP-2", "옛이름", 37.0000, 127.0000)));
        CollectResult second = upserter.upsertAll(List.of(item("UP-2", "새이름", 37.5000, 127.5000)));

        assertThat(second.created()).isZero();
        assertThat(second.updated()).isEqualTo(1);

        Spot updated = spotRepository.findByContentId("UP-2").orElseThrow();
        assertThat(updated.getTitle()).isEqualTo("새이름");
        assertThat(updated.getGeom().getY()).isEqualTo(37.5000);
        assertThat(updated.getGeom().getX()).isEqualTo(127.5000);
    }

    @Test
    void 배치_내_같은_content_id는_한_건으로_병합된다() {
        CollectResult result = upserter.upsertAll(List.of(
                item("UP-3", "먼저", 1.0, 1.0),
                item("UP-3", "나중", 2.0, 2.0)));

        assertThat(result.created()).isEqualTo(1);
        assertThat(spotRepository.findByContentId("UP-3").orElseThrow().getTitle()).isEqualTo("나중");
    }

    @Test
    void contentId나_title이_비면_스킵한다() {
        CollectResult result = upserter.upsertAll(List.of(
                item(null, "아이디없음", 37.0, 127.0),
                item("UP-4", null, 37.0, 127.0),
                item("  ", "공백아이디", 37.0, 127.0)));

        assertThat(result.skipped()).isEqualTo(3);
        assertThat(result.created()).isZero();
        assertThat(spotRepository.findByContentId("UP-4")).isEmpty();
    }
}
