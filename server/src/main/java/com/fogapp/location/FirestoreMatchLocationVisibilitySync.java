package com.fogapp.location;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.FieldValue;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.SetOptions;
import com.google.cloud.firestore.WriteBatch;

/**
 * {@code locations/{firebaseUid}} 문서의 {@code visibleTo} 배열을 갱신해
 * "누가 내 위치를 볼 수 있는가"를 Firestore 쪽에 반영한다(#133).
 *
 * <p>위치 문서 자체({@code lat}·{@code lng}·{@code updatedAt})는 앱이 직접 쓴다 — 여기서는
 * {@code visibleTo}만 건드린다. 두 문서 중 하나가 아직 없어도({@code visibleTo}를 채우기 전에
 * 매칭부터 수락되는 순서) 실패하지 않도록 {@link SetOptions#merge()}로 쓴다.</p>
 *
 * <p>양쪽 문서를 하나의 {@link WriteBatch}로 묶어, 한쪽만 반영되고 다른 쪽은 안 되는
 * 상태가 생기지 않게 한다.</p>
 *
 * <p><b>실패해도 매칭 자체를 막지 않는다.</b> 위치 공유는 매칭의 부가 기능이라, Firestore
 * 쓰기가 실패했다고 매칭 수락·취소가 실패하면 안 된다 — 로그만 남기고 넘어간다. 다음에
 * 상태가 다시 바뀔 때(또는 재시도 로직이 생기면 그때) 다시 맞춰질 수 있다.</p>
 */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true")
public class FirestoreMatchLocationVisibilitySync implements MatchLocationVisibilitySync {

    private static final Logger log = LoggerFactory.getLogger(FirestoreMatchLocationVisibilitySync.class);
    private static final String COLLECTION = "locations";
    private static final String FIELD_VISIBLE_TO = "visibleTo";

    private final Firestore firestore;

    public FirestoreMatchLocationVisibilitySync(Firestore firestore) {
        this.firestore = firestore;
    }

    @Override
    public void grant(String userAFirebaseUid, String userBFirebaseUid) {
        apply(userAFirebaseUid, userBFirebaseUid, FieldValue.arrayUnion(userBFirebaseUid),
                FieldValue.arrayUnion(userAFirebaseUid), "grant");
    }

    @Override
    public void revoke(String userAFirebaseUid, String userBFirebaseUid) {
        apply(userAFirebaseUid, userBFirebaseUid, FieldValue.arrayRemove(userBFirebaseUid),
                FieldValue.arrayRemove(userAFirebaseUid), "revoke");
    }

    private void apply(String userAFirebaseUid, String userBFirebaseUid,
                        FieldValue forA, FieldValue forB, String action) {
        try {
            DocumentReference docA = firestore.collection(COLLECTION).document(userAFirebaseUid);
            DocumentReference docB = firestore.collection(COLLECTION).document(userBFirebaseUid);

            WriteBatch batch = firestore.batch();
            batch.set(docA, java.util.Map.of(FIELD_VISIBLE_TO, forA), SetOptions.merge());
            batch.set(docB, java.util.Map.of(FIELD_VISIBLE_TO, forB), SetOptions.merge());
            batch.commit().get();
        } catch (Exception e) {
            // 클래스 주석 참고 — 위치 공유 실패가 매칭 자체를 막으면 안 된다.
            log.warn("[MatchLocationVisibilitySync] {} 실패 (uidA={}, uidB={}): {}",
                    action, userAFirebaseUid, userBFirebaseUid, e.getMessage());
        }
    }
}
