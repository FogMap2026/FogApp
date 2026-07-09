package com.fogapp.footprint;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
    public Footprint update(Long id, String content, String photoUrl) {
        Footprint footprint = get(id);
        footprint.update(content, photoUrl);
        return footprint;
    }

    @Transactional
    public void delete(Long id) {
        if (!footprintRepository.existsById(id)) {
            throw new NotFoundException("발자취", id);
        }
        footprintRepository.deleteById(id);
    }
}
