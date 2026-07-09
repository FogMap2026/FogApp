package com.fogapp.match;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.common.NotFoundException;

@Service
@Transactional(readOnly = true)
public class MatchService {

    private final MatchRepository matchRepository;

    public MatchService(MatchRepository matchRepository) {
        this.matchRepository = matchRepository;
    }

    @Transactional
    public Match request(Long requesterId, Long addresseeId) {
        if (matchRepository.existsByRequesterIdAndAddresseeId(requesterId, addresseeId)) {
            throw new IllegalArgumentException("이미 요청한 매칭입니다.");
        }
        return matchRepository.save(new Match(requesterId, addresseeId));
    }

    public Match get(Long id) {
        return matchRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("매칭", id));
    }

    public List<Match> listForUser(Long userId) {
        return matchRepository.findAllInvolvingUser(userId);
    }

    @Transactional
    public Match updateStatus(Long id, String status) {
        Match match = get(id);
        match.updateStatus(status);
        return match;
    }

    @Transactional
    public void delete(Long id) {
        if (!matchRepository.existsById(id)) {
            throw new NotFoundException("매칭", id);
        }
        matchRepository.deleteById(id);
    }
}
