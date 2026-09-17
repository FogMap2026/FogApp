package com.fogapp.push;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Firebase 자격증명이 없는 환경(로컬 개발·CI)의 대역.
 *
 * <p>없으면 {@code PushSender} 주입이 실패해 <b>앱 전체가 안 뜬다</b> — 알림은 곁가지인데 서버가
 * 죽는 꼴이다. 여기서는 로그만 남기고 조용히 넘어간다.</p>
 *
 * <p>⚠️ 클래스 이름과 {@code @Bean} 메서드 이름이 같으면 안 된다 — 컴포넌트 스캔이 만드는 빈 이름과
 * 부딪혀 {@code BeanDefinitionOverrideException} 으로 컨텍스트가 아예 안 뜬다(CI 에서 겪었다).</p>
 */
@Configuration
public class PushFallbackConfig {

    private static final Logger log = LoggerFactory.getLogger(PushFallbackConfig.class);

    @Bean
    @ConditionalOnMissingBean(PushSender.class)
    public PushSender noopPushSender() {
        return (userId, title, body, data) ->
                log.debug("푸시 생략(Firebase 꺼짐) userId={} title={}", userId, title);
    }
}
