package com.fogapp.auth;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;

/**
 * Firebase Admin 초기화. {@code firebase.enabled=true} 일 때만 활성화된다.
 * 자격증명은 서비스 계정 JSON 경로(firebase.service-account-path)가 있으면 그것을,
 * 없으면 GOOGLE_APPLICATION_CREDENTIALS 등 애플리케이션 기본 자격증명을 사용한다.
 */
@Configuration
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true")
public class FirebaseConfig {

    @Bean
    public FirebaseApp firebaseApp(
            @Value("${firebase.service-account-path:}") String serviceAccountPath) throws IOException {
        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }

        GoogleCredentials credentials;
        if (StringUtils.hasText(serviceAccountPath)) {
            try (InputStream in = new FileInputStream(serviceAccountPath)) {
                credentials = GoogleCredentials.fromStream(in);
            }
        } else {
            credentials = GoogleCredentials.getApplicationDefault();
        }

        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(credentials)
                .build();
        return FirebaseApp.initializeApp(options);
    }
}
