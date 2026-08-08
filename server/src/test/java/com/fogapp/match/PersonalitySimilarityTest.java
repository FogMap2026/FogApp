package com.fogapp.match;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.within;

import java.util.Map;

import org.junit.jupiter.api.Test;

class PersonalitySimilarityTest {

    @Test
    void 성향이_완전히_같으면_유사도는_1이다() {
        Map<String, Integer> a = Map.of("spontaneity", 70, "restVsRoam", 30, "extraversion", 50);
        Map<String, Integer> b = Map.of("spontaneity", 70, "restVsRoam", 30, "extraversion", 50);

        assertThat(PersonalitySimilarity.similarity(a, b)).isCloseTo(1.0, within(0.0001));
    }

    @Test
    void 세_축_모두_정반대이면_유사도는_0이다() {
        Map<String, Integer> a = Map.of("spontaneity", 0, "restVsRoam", 0, "extraversion", 0);
        Map<String, Integer> b = Map.of("spontaneity", 100, "restVsRoam", 100, "extraversion", 100);

        assertThat(PersonalitySimilarity.similarity(a, b)).isCloseTo(0.0, within(0.0001));
    }

    @Test
    void 한_축만_다르면_유사도는_1과_0_사이다() {
        Map<String, Integer> a = Map.of("spontaneity", 50, "restVsRoam", 50, "extraversion", 50);
        Map<String, Integer> b = Map.of("spontaneity", 100, "restVsRoam", 50, "extraversion", 50);

        double similarity = PersonalitySimilarity.similarity(a, b);

        assertThat(similarity).isLessThan(1.0).isGreaterThan(0.0);
    }

    @Test
    void 축이_모자라면_유사도를_계산할_수_없다() {
        Map<String, Integer> incomplete = Map.of("spontaneity", 50, "restVsRoam", 50);
        Map<String, Integer> full = Map.of("spontaneity", 50, "restVsRoam", 50, "extraversion", 50);

        assertThat(PersonalitySimilarity.hasAllAxes(incomplete)).isFalse();
        assertThatThrownBy(() -> PersonalitySimilarity.similarity(incomplete, full))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
