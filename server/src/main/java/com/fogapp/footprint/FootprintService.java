package com.fogapp.footprint;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.common.ForbiddenException;
import com.fogapp.common.NotFoundException;
import com.fogapp.user.UserRepository;
import com.fogapp.user.UserSummary;

@Service
@Transactional(readOnly = true)
public class FootprintService {

    private final FootprintRepository footprintRepository;
    private final UserRepository userRepository;

    public FootprintService(FootprintRepository footprintRepository, UserRepository userRepository) {
        this.footprintRepository = footprintRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public Footprint create(Long userId, Long spotId, String content, String photoUrl) {
        return footprintRepository.save(new Footprint(userId, spotId, content, photoUrl));
    }

    public Footprint get(Long id) {
        return footprintRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("발자취", id));
    }

    public List<Footprint> listBySpot(Long spotId) {
        return footprintRepository.findBySpotIdOrderByCreatedAtDesc(spotId);
    }

    public List<Footprint> listByUser(Long userId) {
        return footprintRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    @Transactional
    public Footprint update(Long callerId, Long id, String content, String photoUrl) {
        Footprint footprint = get(id);
        requireOwner(callerId, footprint);
        footprint.update(content, photoUrl);
        return footprint;
    }

    @Transactional
    public void delete(Long callerId, Long id) {
        Footprint footprint = get(id);
        requireOwner(callerId, footprint);
        footprintRepository.deleteById(id);
    }

    /**
     * 발자취 목록에 작성자 정보를 붙인다(#71).
     *
     * <p>작성자 조회는 <b>목록 크기와 무관하게 한 번</b>이다. 발자취마다 사용자를 읽으면
     * 20개짜리 목록에 질의가 21번 나간다.</p>
     */
    public List<FootprintResponse> withAuthors(List<Footprint> footprints) {
        if (footprints.isEmpty()) {
            // 빈 목록으로 IN () 을 만들면 SQL 이 깨진다.
            return List.of();
        }

        List<Long> authorIds = footprints.stream().map(Footprint::getUserId).distinct().toList();
        Map<Long, UserSummary> authors = userRepository.findSummariesByIdIn(authorIds).stream()
                .collect(Collectors.toMap(UserSummary::id, Function.identity()));

        return footprints.stream()
                .map(f -> FootprintResponse.from(f, authors.get(f.getUserId())))
                .toList();
    }

    /** 발자취 하나에 작성자 정보를 붙인다(#71). */
    public FootprintResponse withAuthor(Footprint footprint) {
        return withAuthors(List.of(footprint)).get(0);
    }

    private void requireOwner(Long callerId, Footprint footprint) {
        if (!footprint.getUserId().equals(callerId)) {
            throw new ForbiddenException("본인이 작성한 발자취만 수정·삭제할 수 있습니다.");
        }
    }
}
