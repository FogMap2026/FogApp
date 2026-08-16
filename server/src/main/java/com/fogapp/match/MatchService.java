package com.fogapp.match;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.common.ForbiddenException;
import com.fogapp.common.NotFoundException;
import com.fogapp.user.PersonalityScoreParser;
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;
import com.fogapp.user.UserSummary;

@Service
@Transactional(readOnly = true)
public class MatchService {

    private final MatchRepository matchRepository;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    public MatchService(MatchRepository matchRepository, UserRepository userRepository, ObjectMapper objectMapper) {
        this.matchRepository = matchRepository;
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public Match request(Long requesterId, Long addresseeId) {
        if (matchRepository.existsByRequesterIdAndAddresseeId(requesterId, addresseeId)) {
            throw new IllegalArgumentException("이미 요청한 매칭입니다.");
        }
        Match match = new Match(requesterId, addresseeId);
        computeSimilarity(requesterId, addresseeId).ifPresent(match::updateScore);
        return matchRepository.save(match);
    }

    /**
     * 성향이 비슷한 순으로 후보를 추천한다(#37). 본인, 성향 미응답 사용자는 제외한다.
     * 지역/거리 필터는 Phase 5에서 GPS 트랙과 함께 추가한다.
     */
    public List<MatchCandidate> recommendCandidates(Long userId, int limit) {
        Map<String, Integer> myScores = axisScoresOf(userId);
        if (!PersonalitySimilarity.hasAllAxes(myScores)) {
            return List.of();
        }

        return userRepository.findAll().stream()
                .filter(other -> !other.getId().equals(userId))
                .map(other -> toCandidate(other, myScores))
                .filter(Objects::nonNull)
                .sorted(Comparator.comparingDouble(MatchCandidate::similarity).reversed())
                .limit(limit)
                .toList();
    }

    private MatchCandidate toCandidate(User other, Map<String, Integer> myScores) {
        Map<String, Integer> otherScores = axisScoresOf(other);
        if (!PersonalitySimilarity.hasAllAxes(otherScores)) {
            return null;
        }
        return new MatchCandidate(other.getId(), other.getNickname(), PersonalitySimilarity.similarity(myScores, otherScores));
    }

    private Optional<Double> computeSimilarity(Long requesterId, Long addresseeId) {
        Map<String, Integer> requesterScores = axisScoresOf(requesterId);
        Map<String, Integer> addresseeScores = axisScoresOf(addresseeId);
        if (!PersonalitySimilarity.hasAllAxes(requesterScores) || !PersonalitySimilarity.hasAllAxes(addresseeScores)) {
            return Optional.empty();
        }
        return Optional.of(PersonalitySimilarity.similarity(requesterScores, addresseeScores));
    }

    private Map<String, Integer> axisScoresOf(Long userId) {
        return userRepository.findById(userId)
                .map(this::axisScoresOf)
                .orElseGet(Map::of);
    }

    private Map<String, Integer> axisScoresOf(User user) {
        return PersonalityScoreParser.parseAxisScores(objectMapper, user.getPersonalityScores());
    }

    public Match get(Long id) {
        return matchRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("매칭", id));
    }

    public List<Match> listForUser(Long userId) {
        return matchRepository.findAllInvolvingUser(userId);
    }

    /**
     * 매칭 목록에 상대방 정보(닉네임·프로필 이미지)와 방향(SENT/RECEIVED)을 붙인다.
     *
     * <p>발자취 목록({@code FootprintService.withAuthors})과 같은 이유로 상대방 조회는
     * 목록 크기와 무관하게 한 번이다 — 매칭마다 읽으면 N+1이 난다.</p>
     */
    public List<MatchResponse> withCounterparts(List<Match> matches, Long viewerId) {
        if (matches.isEmpty()) {
            return List.of();
        }
        Set<Long> counterpartIds = matches.stream()
                .map(match -> counterpartIdOf(match, viewerId))
                .collect(Collectors.toSet());
        Map<Long, UserSummary> summariesById = userRepository.findSummariesByIdIn(counterpartIds).stream()
                .collect(Collectors.toMap(UserSummary::id, summary -> summary));
        return matches.stream()
                .map(match -> MatchResponse.from(match, viewerId, summariesById.get(counterpartIdOf(match, viewerId))))
                .toList();
    }

    public MatchResponse withCounterpart(Match match, Long viewerId) {
        return withCounterparts(List.of(match), viewerId).get(0);
    }

    private Long counterpartIdOf(Match match, Long viewerId) {
        return match.getRequesterId().equals(viewerId) ? match.getAddresseeId() : match.getRequesterId();
    }

    /** 수락/거절은 요청을 받은 쪽(addressee)만 할 수 있다(#52). */
    @Transactional
    public Match updateStatus(Long callerId, Long id, String status) {
        Match match = get(id);
        if (!match.getAddresseeId().equals(callerId)) {
            throw new ForbiddenException("매칭 상태 변경은 요청 대상자만 할 수 있습니다.");
        }
        match.updateStatus(status);
        return match;
    }

    /** 요청자·대상자 둘 중 한쪽이면 매칭을 취소(삭제)할 수 있다(#52). */
    @Transactional
    public void delete(Long callerId, Long id) {
        Match match = get(id);
        if (!match.getRequesterId().equals(callerId) && !match.getAddresseeId().equals(callerId)) {
            throw new ForbiddenException("본인이 관련된 매칭만 취소할 수 있습니다.");
        }
        matchRepository.deleteById(id);
    }
}
