package com.fogapp.location;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.google.cloud.firestore.Firestore;
import com.google.firebase.FirebaseApp;
import com.google.firebase.cloud.FirestoreClient;

/**
 * {@code firebase.enabled=true}일 때 {@link Firestore} 클라이언트를 빈으로 노출한다.
 *
 * <p>{@link com.fogapp.auth.FirebaseConfig}가 만든 {@link FirebaseApp}에 얹혀 간다 —
 * 서비스 계정 자격증명을 여기서 다시 읽지 않는다. 자격증명에 이미 Firestore 접근 권한이
 * 포함돼 있어야 한다(Firebase 콘솔에서 Firestore를 켜면 기본 서비스 계정이 자동으로 갖는다).</p>
 */
@Configuration
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true")
public class FirestoreConfig {

    @Bean
    public Firestore firestore(FirebaseApp firebaseApp) {
        return FirestoreClient.getFirestore(firebaseApp);
    }
}
