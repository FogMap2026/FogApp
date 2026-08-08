package com.fogapp.spot;

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

/**
 * V2 트리거(lat/lng -> geom 자동 채움)와 ST_DWithin 반경 쿼리를
 * 실제 PostGIS(docker-compose 와 동일한 이미지)에 대해 검증한다. (#6)
 */
@Testcontainers
@SpringBootTest
class SpotRepositoryIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private SpotRepository spotRepository;

    @Test
    void 유효한_좌표는_geom이_자동으로_채워진다() {
        Spot saved = spotRepository.save(new Spot(
                "T-1", "12", "테스트 스팟", "서울시 어딘가", null, "1", "1", null, null, null, null,
                37.5665, 126.9780));

        Spot reloaded = spotRepository.findById(saved.getId()).orElseThrow();

        assertThat(reloaded.getGeom()).isNotNull();
        assertThat(reloaded.getGeom().getX()).isEqualTo(126.9780);
        assertThat(reloaded.getGeom().getY()).isEqualTo(37.5665);
    }

    @Test
    void 좌표가_없으면_geom은_null이지만_행은_저장된다() {
        Spot saved = spotRepository.save(new Spot(
                "T-2", "12", "좌표없는 스팟", null, null, "1", "1", null, null, null, null,
                null, null));

        Spot reloaded = spotRepository.findById(saved.getId()).orElseThrow();

        assertThat(reloaded.getGeom()).isNull();
    }

    @Test
    void 범위를_벗어난_이상치_좌표는_geom을_null로_남긴다() {
        Spot saved = spotRepository.save(new Spot(
                "T-3", "12", "이상치 스팟", null, null, "1", "1", null, null, null, null,
                999.0, 126.9780));

        Spot reloaded = spotRepository.findById(saved.getId()).orElseThrow();

        assertThat(reloaded.getGeom()).isNull();
    }

    @Test
    void 반경_내_스팟만_ST_DWithin으로_조회된다() {
        // 광화문 (중심에서 약 1.2km)
        spotRepository.save(new Spot("T-4", "12", "광화문 스팟", null, null, "1", "1", null, null, null, null,
                37.5759, 126.9769));
        // 부산 (반경 밖, 수백 km)
        spotRepository.save(new Spot("T-5", "12", "부산 스팟", null, null, "1", "1", null, null, null, null,
                35.1796, 129.0756));

        List<Spot> found = spotRepository.findWithinRadius(37.5665, 126.9780, 5000);

        assertThat(found).extracting(Spot::getContentId).contains("T-4").doesNotContain("T-5");
    }
}
