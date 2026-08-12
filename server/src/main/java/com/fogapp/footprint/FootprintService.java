package com.fogapp.footprint;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.common.ForbiddenException;
import com.fogapp.common.NotFoundException;
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;

@Service
@Transactional(readOnly = true)
public class FootprintService {

    private final FootprintRepository footprintRepository;
    private final FootprintLikeRepository footprintLikeRepository;
    private final UserRepository userRepository;

    public FootprintService(FootprintRepository footprintRepository,
                            FootprintLikeRepository footprintLikeRepository,
                            UserRepository userRepository) {
        this.footprintRepository = footprintRepository;
        this.footprintLikeRepository = footprintLikeRepository;
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

    /** 발자취 하나를 응답으로 바꾼다(#71/#72). 단건 조회·작성·수정 직후에 쓴다. */
    public FootprintResponse toResponse(Footprint footprint, Long viewerId) {
        User author = userRepository.findById(footprint.getUserId()).orElse(null);
        boolean liked = viewerId != null
                && footprintLikeRepository.existsByFootprintIdAndUserId(footprint.getId(), viewerId);
        return FootprintResponse.from(footprint, author, liked);
    }

    /**
     * 발자취 목록을 응답으로 바꾼다(#71/#72). 작성자·좋아요 여부를 각각 한 번의 배치 질의로
     * 가져온다 — 발자취마다 조회하면 목록 하나에 N번씩 두 번(작성자, 좋아요) 질의하게 된다.
     */
    public List<FootprintResponse> toResponses(List<Footprint> footprints, Long viewerId) {
        if (footprints.isEmpty()) {
            return List.of();
        }

        Set<Long> authorIds = footprints.stream().map(Footprint::getUserId).collect(Collectors.toSet());
        Map<Long, User> authorsById = userRepository.findAllById(authorIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        Set<Long> likedFootprintIds = likedFootprintIdsAmong(viewerId, footprints);

        return footprints.stream()
                .map(footprint -> FootprintResponse.from(
                        footprint,
                        authorsById.get(footprint.getUserId()),
                        likedFootprintIds.contains(footprint.getId())))
                .toList();
    }

    private Set<Long> likedFootprintIdsAmong(Long viewerId, Collection<Footprint> footprints) {
        if (viewerId == null) {
            return Set.of();
        }
        return footprintLikeRepository.findLikedFootprintIds(
                viewerId, footprints.stream().map(Footprint::getId).toList());
    }

    private void requireOwner(Long callerId, Footprint footprint) {
        if (!footprint.getUserId().equals(callerId)) {
            throw new ForbiddenException("본인이 작성한 발자취만 수정·삭제할 수 있습니다.");
        }
    }
}
