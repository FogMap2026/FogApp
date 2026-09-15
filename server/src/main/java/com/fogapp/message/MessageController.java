package com.fogapp.message;

import java.util.List;

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

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 친구끼리 메시지. 대화방은 수락된 매칭 한 건이라 경로도 매칭 아래에 둔다.
 *
 * <p>실시간 연결(WebSocket·푸시)은 없다 — 앱이 대화방을 연 동안 {@code afterId} 로 주기 조회한다.
 * 푸시 알림은 #134(FCM)에서.</p>
 */
@RestController
@RequestMapping("/api/matches/{matchId}/messages")
public class MessageController {

    private final MessageService messageService;

    public MessageController(MessageService messageService) {
        this.messageService = messageService;
    }

    @GetMapping
    public List<MessageResponse> list(@AuthenticationPrincipal AuthUser me,
                                      @PathVariable Long matchId,
                                      @RequestParam(required = false) Long afterId) {
        return messageService.list(me.userId(), matchId, afterId);
    }

    @PostMapping
    public ResponseEntity<MessageResponse> send(@AuthenticationPrincipal AuthUser me,
                                                @PathVariable Long matchId,
                                                @Valid @RequestBody MessageCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(messageService.send(me.userId(), matchId, request.content()));
    }
}
