package com.fogapp.conquest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

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
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;
import com.fogapp.visit.VisitService;

/**
 * 지역별 정복률 집계(#51)를 실제 PostGIS로 검증한다.
 * 집계가 SQL에 있으므로 컨테이너 없이는 의미 있는 검증이 되지 않는다.
 */
@Testcontainers
@SpringBootTest
class ConquestServiceIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    /** @SpringBootTest 는 메서드 간 롤백이 없어 데이터가 공유된다 — 테스트마다 고유 지역 코드를 쓴다. */
    private static final AtomicInteger SEQ = new AtomicInteger();

    private static final double LAT = 35.8562;
    private static final double LNG = 129.2247;

    @Autowired
    private ConquestService conquestService;

    @Autowired
    private SpotRepository spotRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private VisitService visitService;

    private User newUser() {
        int n = SEQ.incrementAndGet();
        return userRepository.save(new User("conquest-uid-" + n, "c" + n + "@test.io", "탐험가" + n, null));
    }

    private Spot newSpot(String areaCode, String sigunguCode, String addr1) {
        int n = SEQ.incrementAndGet();
        return spotRepository.save(new Spot(
                "CONQ-" + n, "12", "정복테스트-" + n, addr1, null,
                areaCode, sigunguCode, null, null, null, null, LAT, LNG));
    }

    private ConquestResponse regionOf(List<ConquestResponse> all, String regionCode) {
        return all.stream().filter(r -> r.regionCode().equals(regionCode)).findFirst().orElseThrow();
    }

    @Test
    void 시군구_단위로_집계하고_정복률을_계산한다() {
        String area = "AREA-" + SEQ.incrementAndGet();
        User user = newUser();

        // 같은 시/도 안의 서로 다른 시/군/구 — 시/도로 뭉치지 않아야 한다.
        Spot gyeongju1 = newSpot(area, "1", "경상북도 경주시 첨성로 169");
        newSpot(area, "1", "경상북도 경주시 원화로 185");
        newSpot(area, "2", "경상북도 안동시 축제장길 240");

        visitService.verify(user.getId(), user.getFirebaseUid(), gyeongju1.getId(),
                "https://storage/a.jpg", LAT, LNG);

        List<ConquestResponse> all = conquestService.myConquest(user.getId());

        ConquestResponse gyeongju = regionOf(all, area + "-1");
        assertThat(gyeongju.totalSpots()).isEqualTo(2);
        assertThat(gyeongju.visitedSpots()).isEqualTo(1);
        assertThat(gyeongju.rate()).isCloseTo(0.5, within(1e-9));
        assertThat(gyeongju.regionName()).isEqualTo("경상북도 경주시");

        ConquestResponse andong = regionOf(all, area + "-2");
        assertThat(andong.totalSpots()).isEqualTo(1);
        assertThat(andong.visitedSpots()).isZero();
        assertThat(andong.rate()).isZero();
    }

    @Test
    void 한_번도_방문하지_않은_지역도_분모와_함께_나온다() {
        // LEFT JOIN 조건을 WHERE 로 내리면 이 지역이 통째로 사라진다 — 그 회귀를 막는 테스트다.
        String area = "AREA-" + SEQ.incrementAndGet();
        User user = newUser();
        newSpot(area, "9", "전라남도 여수시 오동도로 222");

        ConquestResponse region = regionOf(conquestService.myConquest(user.getId()), area + "-9");

        assertThat(region.totalSpots()).isEqualTo(1);
        assertThat(region.visitedSpots()).isZero();
    }

    @Test
    void 다른_사용자의_인증은_내_정복률에_반영되지_않는다() {
        String area = "AREA-" + SEQ.incrementAndGet();
        User me = newUser();
        User other = newUser();
        Spot spot = newSpot(area, "3", "강원도 강릉시 경강로 2024");

        visitService.verify(other.getId(), other.getFirebaseUid(), spot.getId(),
                "https://storage/b.jpg", LAT, LNG);

        assertThat(regionOf(conquestService.myConquest(me.getId()), area + "-3").visitedSpots()).isZero();
        assertThat(regionOf(conquestService.myConquest(other.getId()), area + "-3").visitedSpots()).isEqualTo(1);
    }

    @Test
    void 주소가_없으면_지역코드로_폴백한다() {
        String area = "AREA-" + SEQ.incrementAndGet();
        User user = newUser();
        newSpot(area, "7", null); // 관광공사 데이터에 주소가 빈 스팟이 있다

        ConquestResponse region = regionOf(conquestService.myConquest(user.getId()), area + "-7");

        assertThat(region.regionName()).isEqualTo(area + "-7");
    }

    @Test
    void 시군구코드가_없는_스팟도_집계에서_빠지지_않는다() {
        String area = "AREA-" + SEQ.incrementAndGet();
        User user = newUser();
        newSpot(area, null, "제주특별자치도 제주시 첨단로 242");

        ConquestResponse region = regionOf(conquestService.myConquest(user.getId()), area + "-");

        assertThat(region.totalSpots()).isEqualTo(1);
        assertThat(region.regionName()).isEqualTo("제주특별자치도 제주시");
    }
}
