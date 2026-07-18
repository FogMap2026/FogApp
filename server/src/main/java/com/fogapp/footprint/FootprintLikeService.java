package com.fogapp.footprint;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.common.NotFoundException;

/**
 * 발자취 좋아요·공감(#23). 이미 좋아요한 상태에서 좋아요, 좋아요하지 않은 상태에서 취소는
 * 에러 없이 무시한다(멱등 처리) — 클라이언트가 토글 버튼 상태를 매번 정확히 추적하지 않아도 되게 한다.
 */
@Service
@Transactional(readOnly = true)
public class FootprintLikeService {

    private final FootprintLikeRepository footprintLikeRepository;
    private final FootprintRepository footprintRepository;

    public FootprintLikeService(FootprintLikeRepository footprintLikeRepository,
                                 FootprintRepository footprintRepository) {
        this.footprintLikeRepository = footprintLikeRepository;
        this.footprintRepository = footprintRepository;
    }

    @Transactional
    public void like(Long footprintId, Long userId) {
        if (!footprintRepository.existsById(footprintId)) {
            throw new NotFoundException("발자취", footprintId);
        }
        if (footprintLikeRepository.existsByFootprintIdAndUserId(footprintId, userId)) {
            return;
        }
        footprintLikeRepository.save(new FootprintLike(footprintId, userId));
        footprintRepository.incrementLikeCount(footprintId);
    }

    @Transactional
    public void unlike(Long footprintId, Long userId) {
        footprintLikeRepository.findByFootprintIdAndUserId(footprintId, userId)
                .ifPresent(like -> {
                    footprintLikeRepository.delete(like);
                    footprintRepository.decrementLikeCount(footprintId);
                });
    }
}
