package com.fogapp.controller;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 서버 상태 확인용 헬스체크 엔드포인트.
 * GET /api/health -> {"status":"UP","service":"fogapp-server"}
 */
@RestController
public class HealthController {

    @GetMapping("/api/health")
    public Map<String, String> health() {
        return Map.of(
                "status", "UP",
                "service", "fogapp-server"
        );
    }
}
