package com.fogapp.footprint;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.common.ForbiddenException;
import com.fogapp.common.NotFoundException;

@Service
@Transactional(readOnly = true)
public class FootprintService {

    private final FootprintRepository footprintRepository;

    public FootprintService(FootprintRepository footprintRepository) {
        this.footprintRepository = footprintRepository;
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

    private void requireOwner(Long callerId, Footprint footprint) {
        if (!footprint.getUserId().equals(callerId)) {
            throw new ForbiddenException("본인이 작성한 발자취만 수정·삭제할 수 있습니다.");
        }
    }
}
