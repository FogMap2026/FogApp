package com.fogapp.visit;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.fogapp.common.NotFoundException;
import com.fogapp.spot.SpotRepository;

/**
 * 방문 인증(#48). 탐험 루프의 기록 계층 — 여기서 생긴 visits 행이
 * 안개 해제(3-5)·스팟 해금(3-6)·정복률(3-7)의 공통 근거가 된다.
 */
@Service
@Transactional(readOnly = true)
public class VisitService {

    private final VisitRepository visitRepository;
    private final SpotRepository spotRepository;
    private final VisitProperties properties;
    private final VisitPhotoUrlValidator photoUrlValidator;

    public VisitService(VisitRepository visitRepository,
                        SpotRepository spotRepository,
                        VisitProperties properties,
                        VisitPhotoUrlValidator photoUrlValidator) {
        this.visitRepository = visitRepository;
        this.spotRepository = spotRepository;
        this.properties = properties;
        this.photoUrlValidator = photoUrlValidator;
    }

    /**
     * 방문을 인증한다. userId·firebaseUid 는 인증 필터가 세운 현재 사용자여야 하며
     * 요청 본문에서 받지 않는다.
     *
     * <p>순서가 중요하다 — 좌표 범위 → photoUrl 출처 → 스팟 존재 → 중복 → 반경 순으로 검사한다.
     * 반경을 먼저 보면 "없는 스팟"과 "멀리 있는 스팟"이 같은 응답으로 뭉개진다.</p>
     */
    @Transactional
    public Visit verify(Long userId, String firebaseUid, Long spotId, String photoUrl, double lat, double lng) {
        // 범위를 벗어난 좌표는 PostGIS geography 캐스팅에서 예외가 되어 500 이 된다 — 먼저 400 으로 거른다.
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            throw new IllegalArgumentException("좌표 범위가 올바르지 않습니다. (lat=" + lat + ", lng=" + lng + ")");
        }

        // Storage Rules(#56)가 업로드를 본인 경로로 잠가도, 서버가 그 경로를 요구하지 않으면
        // 아무 URL이나 넣어 인증이 성립한다. 둘이 짝을 이뤄야 방어가 닫힌다.
        photoUrlValidator.validate(photoUrl, firebaseUid, spotId);

        if (!spotRepository.existsById(spotId)) {
            throw new NotFoundException("스팟", spotId);
        }

        if (visitRepository.existsByUserIdAndSpotId(userId, spotId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 인증한 스팟입니다.");
        }

        if (!visitRepository.isWithinSpotRadius(spotId, lat, lng, properties.getRadiusMeters())) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,
                    "스팟 반경 " + (long) properties.getRadiusMeters() + "m 밖에서는 인증할 수 없습니다.");
        }

        return visitRepository.save(new Visit(userId, spotId, photoUrl, lat, lng));
    }

    /**
     * 이미 인증한 스팟이면 409 로 막는다(#76).
     *
     * <p>사진 업로드 전에 부른다. 업로드는 스팟당 1장만 남기므로(이전 파일 삭제),
     * 이미 인증된 스팟에 다시 올리면 <b>이미 기록된 방문의 사진이 지워진다.</b>
     * 어차피 인증은 409 로 실패할 요청이니, 파일에 손대기 전에 여기서 끊는다.</p>
     */
    public void requireNotVerified(Long userId, Long spotId) {
        if (visitRepository.existsByUserIdAndSpotId(userId, spotId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 인증한 스팟입니다.");
        }
    }

    /** 내 인증 목록(최신순). 앱이 걷힌 안개 영역을 복원할 때 쓴다. */
    public List<Visit> listByUser(Long userId) {
        return visitRepository.findByUserIdOrderByVerifiedAtDesc(userId);
    }
}
