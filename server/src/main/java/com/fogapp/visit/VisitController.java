package com.fogapp.visit;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 방문 인증 API(#48). 탐험 루프의 "인증" 단계.
 *
 * <p>사용자는 항상 인증 필터가 세운 {@link AuthUser} 에서 얻는다 — 요청으로 받지 않는다.</p>
 *
 * <p>사진 흐름(팀 결정 B안): 앱이 ① {@code POST /api/visits/photo} 로 사진을 올려 URL을 받고,
 * ② 그 URL을 {@code POST /api/visits} 에 넘겨 방문을 인증한다. Firebase Storage 는
 * 무료 요금제 제약으로 쓰지 않고 서버가 직접 보관한다(로그인·푸시는 Firebase 유지).</p>
 */
@RestController
@RequestMapping("/api/visits")
public class VisitController {

    private final VisitService visitService;
    private final VisitPhotoStorage photoStorage;

    public VisitController(VisitService visitService, VisitPhotoStorage photoStorage) {
        this.visitService = visitService;
        this.photoStorage = photoStorage;
    }

    /**
     * 인증 사진 업로드. 저장 경로는 서버가 정하며 로그인한 사용자 본인 경로에만 쓴다.
     *
     * <p>응답의 {@code photoUrl} 을 <b>그대로</b> {@code POST /api/visits} 에 넘겨야 한다.</p>
     */
    @PostMapping("/photo")
    public ResponseEntity<VisitPhotoResponse> uploadPhoto(@AuthenticationPrincipal AuthUser me,
                                                          @RequestParam("spotId") Long spotId,
                                                          @RequestParam("file") MultipartFile file) {
        String photoUrl = photoStorage.store(me.firebaseUid(), spotId, file);
        return ResponseEntity.status(HttpStatus.CREATED).body(new VisitPhotoResponse(photoUrl));
    }

    /**
     * 인증 사진 조회. 발자취·정복 기록은 다른 탐험가도 보므로 로그인 사용자면 열람할 수 있다
     * (쓰기는 본인만 — {@link VisitPhotoStorage} 참고).
     */
    @GetMapping("/photos/{firebaseUid}/{spotId}/{fileName}")
    public ResponseEntity<Resource> photo(@PathVariable String firebaseUid,
                                          @PathVariable String spotId,
                                          @PathVariable String fileName) {
        Resource resource = photoStorage.load(firebaseUid, spotId, fileName);
        if (!resource.exists()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .header("Content-Type", photoStorage.contentTypeOf(fileName))
                .body(resource);
    }

    /** 방문 인증. 스팟 반경 밖이면 422, 이미 인증한 스팟이면 409. */
    @PostMapping
    public ResponseEntity<VisitResponse> verify(@AuthenticationPrincipal AuthUser me,
                                                @Valid @RequestBody VisitCreateRequest request) {
        Visit visit = visitService.verify(
                me.userId(), me.firebaseUid(), request.spotId(),
                request.photoUrl(), request.lat(), request.lng());
        return ResponseEntity.status(HttpStatus.CREATED).body(VisitResponse.from(visit));
    }

    /** 내 인증 목록(최신순). 앱이 걷힌 안개 영역과 해금된 스팟을 복원할 때 쓴다. */
    @GetMapping
    public List<VisitResponse> myVisits(@AuthenticationPrincipal AuthUser me) {
        return visitService.listByUser(me.userId()).stream()
                .map(VisitResponse::from)
                .toList();
    }
}
