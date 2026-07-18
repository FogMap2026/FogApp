package com.fogapp.spot;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.web.server.ResponseStatusException;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

/**
 * 스팟 조회(#7)를 실제 PostGIS로 검증한다. HTTP 계층 대신 서비스 레벨로 검증해
 * 이후 보안(#4)이 붙어도 영향받지 않게 한다.
 */
@Testcontainers
@SpringBootTest
class SpotQueryServiceIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private SpotQueryService spotQueryService;

    @Autowired
    private SpotRepository spotRepository;

    private Spot spot(String contentId, String areaCode, Double lat, Double lng) {
        return new Spot(contentId, "12", "스팟-" + contentId, "주소", null,
                areaCode, "1", null, null, null, null, lat, lng);
    }

    @Test
    void 지역_코드별로_페이징_조회한다() {
        // @SpringBootTest 는 메서드 간 롤백이 없어 데이터가 공유되므로, 이 테스트 전용 지역 코드를 쓴다.
        String area = "AREA-REGION-TEST";
        for (int i = 0; i < 3; i++) {
            spotRepository.save(spot("REG-" + i, area, 37.5 + i * 0.01, 127.0));
        }
        spotRepository.save(spot("REG-OTHER", "AREA-OTHER-TEST", 35.1, 129.0)); // 다른 지역

        PageResponse<SpotResponse> page = spotQueryService.findByRegion(area, 0, 2);

        assertThat(page.size()).isEqualTo(2);
        assertThat(page.totalElements()).isEqualTo(3);
        assertThat(page.totalPages()).isEqualTo(2);
        assertThat(page.content()).allSatisfy(s -> assertThat(s.areaCode()).isEqualTo(area));
    }

    @Test
    void 페이지_크기는_상한을_넘지_않는다() {
        PageResponse<SpotResponse> page = spotQueryService.findByRegion("99", 0, 100_000);
        assertThat(page.size()).isEqualTo(SpotQueryService.MAX_PAGE_SIZE);
    }

    @Test
    void 반경_내_스팟만_가까운_순으로_조회한다() {
        spotRepository.save(spot("NEAR", "1", 37.5759, 126.9769)); // 광화문(중심에서 ~1.2km)
        spotRepository.save(spot("FAR", "6", 35.1796, 129.0756));  // 부산(반경 밖)

        List<SpotResponse> nearby = spotQueryService.findNearby(37.5665, 126.9780, 5000);

        assertThat(nearby).extracting(SpotResponse::contentId).contains("NEAR").doesNotContain("FAR");
    }

    @Test
    void 최대_반경을_넘으면_400을_던진다() {
        assertThatThrownBy(() -> spotQueryService.findNearby(37.5, 127.0, 999_999))
                .isInstanceOf(ResponseStatusException.class);
    }
}
