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

import com.fogapp.user.User;
import com.fogapp.user.UserRepository;
import com.fogapp.visit.Visit;
import com.fogapp.visit.VisitRepository;

/**
 * 스팟 조회(#7)를 실제 PostGIS로 검증한다. HTTP 계층 대신 서비스 레벨로 검증해
 * 이후 보안(#4)이 붙어도 영향받지 않게 한다.
 *
 * <p>#50 해금 판정도 여기서 검증한다 — 같은 스팟이라도 <b>조회한 사용자에 따라</b>
 * {@code unlocked} 와 {@code overview} 가 달라져야 한다.</p>
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

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private VisitRepository visitRepository;

    /** area_code 는 VARCHAR(16) 이다 — 테스트용 지역 코드도 16자를 넘기면 저장에서 깨진다. */
    private Spot spot(String contentId, String areaCode, Double lat, Double lng) {
        return new Spot(contentId, "12", "스팟-" + contentId, "주소", null,
                areaCode, "1", null, null, null, "이곳의 소개 글", lat, lng);
    }

    private User user(String n) {
        return userRepository.save(new User("spot-it-uid-" + n, n + "@test.io", "탐험가" + n, null));
    }

    /** 인증(visits) 한 건을 만들어 해금 상태를 준비한다. */
    private void visit(Long userId, Spot spot) {
        visitRepository.save(new Visit(userId, spot.getId(), "/photo.jpg", spot.getLat(), spot.getLng()));
    }

    @Test
    void 지역_코드별로_페이징_조회한다() {
        // @SpringBootTest 는 메서드 간 롤백이 없어 데이터가 공유되므로, 이 테스트 전용 지역 코드를 쓴다.
        String area = "AREA-REGION-TEST";
        for (int i = 0; i < 3; i++) {
            spotRepository.save(spot("REG-" + i, area, 37.5 + i * 0.01, 127.0));
        }
        spotRepository.save(spot("REG-OTHER", "AREA-OTHER-TEST", 35.1, 129.0)); // 다른 지역

        PageResponse<SpotResponse> page = spotQueryService.findByRegion(user("region").getId(), area, 0, 2);

        assertThat(page.size()).isEqualTo(2);
        assertThat(page.totalElements()).isEqualTo(3);
        assertThat(page.totalPages()).isEqualTo(2);
        assertThat(page.content()).allSatisfy(s -> assertThat(s.areaCode()).isEqualTo(area));
    }

    @Test
    void 페이지_크기는_상한을_넘지_않는다() {
        PageResponse<SpotResponse> page = spotQueryService.findByRegion(user("page").getId(), "99", 0, 100_000);
        assertThat(page.size()).isEqualTo(SpotQueryService.MAX_PAGE_SIZE);
    }

    @Test
    void 반경_내_스팟만_가까운_순으로_조회한다() {
        spotRepository.save(spot("NEAR", "1", 37.5759, 126.9769)); // 광화문(중심에서 ~1.2km)
        spotRepository.save(spot("FAR", "6", 35.1796, 129.0756));  // 부산(반경 밖)

        List<SpotResponse> nearby = spotQueryService.findNearby(user("radius").getId(), 37.5665, 126.9780, 5000);

        assertThat(nearby).extracting(SpotResponse::contentId).contains("NEAR").doesNotContain("FAR");
    }

    @Test
    void 최대_반경을_넘으면_400을_던진다() {
        assertThatThrownBy(() -> spotQueryService.findNearby(user("over").getId(), 37.5, 127.0, 999_999))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void 인증하지_않은_스팟은_잠긴_채_소개를_숨긴다() {
        String area = "AREA-LOCK-TEST";
        spotRepository.save(spot("LOCKED", area, 37.5, 127.0));

        SpotResponse response = spotQueryService.findByRegion(user("locked").getId(), area, 0, 10)
                .content().get(0);

        assertThat(response.unlocked()).isFalse();
        // 앱에서만 가리면 API 직접 호출로 우회된다 — 서버가 필드 자체를 비운다.
        assertThat(response.overview()).isNull();
        // 어디로 갈지 정하는 데 필요한 정보는 그대로 내려간다.
        assertThat(response.title()).isNotNull();
        assertThat(response.lat()).isNotNull();
    }

    @Test
    void 인증한_스팟은_해금되어_소개가_열린다() {
        String area = "AREA-UNLOCK-TEST";
        Spot unlocked = spotRepository.save(spot("UNLOCKED", area, 37.5, 127.0));
        Long userId = user("unlocked").getId();
        visit(userId, unlocked);

        SpotResponse response = spotQueryService.findByRegion(userId, area, 0, 10).content().get(0);

        assertThat(response.unlocked()).isTrue();
        assertThat(response.overview()).isEqualTo("이곳의 소개 글");
    }

    @Test
    void 해금은_사용자마다_따로_판정된다() {
        String area = "AREA-PERUSER";
        Spot target = spotRepository.save(spot("PERUSER", area, 37.5, 127.0));
        Long explorer = user("explorer").getId();
        Long stranger = user("stranger").getId();
        visit(explorer, target);

        // 남이 인증했다고 내 화면까지 열리면 탐험의 보상이 성립하지 않는다.
        assertThat(spotQueryService.findByRegion(stranger, area, 0, 10).content().get(0).unlocked()).isFalse();
        assertThat(spotQueryService.findByRegion(explorer, area, 0, 10).content().get(0).unlocked()).isTrue();
    }

    @Test
    void 반경_조회도_해금을_반영한다() {
        Spot target = spotRepository.save(spot("NEAR-UNLOCK", "1", 37.5760, 126.9770));
        Long userId = user("nearby-unlock").getId();
        visit(userId, target);

        SpotResponse response = spotQueryService.findNearby(userId, 37.5760, 126.9770, 500).stream()
                .filter(s -> "NEAR-UNLOCK".equals(s.contentId()))
                .findFirst()
                .orElseThrow();

        assertThat(response.unlocked()).isTrue();
        assertThat(response.overview()).isEqualTo("이곳의 소개 글");
    }
}
