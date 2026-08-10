package com.fogapp.conquest;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 지역별 정복률(#51). 탐험 루프의 수치적 보상 — 안개 해제(3-5)가 시각적 보상이라면 이쪽은 숫자다.
 */
@Service
@Transactional(readOnly = true)
public class ConquestService {

    private final ConquestRepository conquestRepository;

    public ConquestService(ConquestRepository conquestRepository) {
        this.conquestRepository = conquestRepository;
    }

    /** 내 지역별 정복률 전체. 전국 시/군/구는 250개 남짓이라 페이징하지 않는다. */
    public List<ConquestResponse> myConquest(Long userId) {
        return conquestRepository.aggregate(userId).stream()
                .map(ConquestResponse::from)
                .toList();
    }
}
