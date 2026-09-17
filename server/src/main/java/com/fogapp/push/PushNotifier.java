package com.fogapp.push;

import java.util.Map;

import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import com.fogapp.match.Match;
import com.fogapp.user.UserRepository;
import com.fogapp.user.UserSummary;

/**
 * «무슨 일이 생겼을 때 누구에게 무슨 문구로 보내나»를 한곳에 모은다(#134, 6-4).
 *
 * <p>보내는 것은 <b>서버가 만드는 이벤트 셋</b>뿐이다 — 친구 요청·수락·새 메시지. 이 셋은 앱이
 * 꺼져 있어도 서버에서 생기므로 푸시로만 알릴 수 있다.</p>
 *
 * <p>⛔ <b>스팟 근접은 푸시로 보내지 않는다.</b> 근접을 판정하려면 앱이 꺼진 동안에도 위치를 받아야
 * 하는데, 그 백그라운드 위치 수집은 취소됐고(#135) 방침·위치정보 신고 접수본에도
 * 「위치정보는 앱 실행 중에만 수집」으로 적혀 있다. 근접은 지금처럼 화면 안에서만 알린다(#46).</p>
 *
 * <p><b>발송은 커밋 뒤에 한다</b>({@link #afterCommit}) — 이유 둘. ① 커밋이 실패하면 저장은 안 됐는데
 * 알림만 간 «유령 알림»이 되고, 들어가 보면 아무것도 없다. ② {@code FirebaseMessaging.send} 는 기기마다
 * 도는 동기 네트워크 호출이라, 트랜잭션 안에서 부르면 그동안 <b>DB 커넥션을 쥔 채</b> 응답이 늦어진다
 * (#193 에서 탈퇴가 같은 이유로 트랜잭션 밖으로 나갔다 — 메시지는 그보다 훨씬 자주 온다).</p>
 *
 * <p>문구에는 <b>보낸 사람 닉네임까지만</b> 넣는다 — 메시지 내용은 잠금화면에 그대로 뜨고,
 * 그건 방침 5장의 「그 친구에게만 공개」와 어긋난다(#134 결정, 09-17).</p>
 */
@Component
public class PushNotifier {

    private final PushSender pushSender;
    private final UserRepository userRepository;

    public PushNotifier(PushSender pushSender, UserRepository userRepository) {
        this.pushSender = pushSender;
        this.userRepository = userRepository;
    }

    /** 친구 요청이 왔다 — 받는 사람은 대상자. */
    public void friendRequested(Match match) {
        afterCommit(() -> pushSender.send(
                match.getAddresseeId(),
                "새 친구 요청",
                nicknameOf(match.getRequesterId()) + "님이 친구 요청을 보냈어요.",
                Map.of("type", "friend_request", "matchId", String.valueOf(match.getId()))));
    }

    /** 내가 보낸 요청이 수락됐다 — 받는 사람은 요청자. */
    public void friendAccepted(Match match) {
        afterCommit(() -> pushSender.send(
                match.getRequesterId(),
                "친구가 됐어요",
                nicknameOf(match.getAddresseeId()) + "님이 친구 요청을 수락했어요.",
                Map.of("type", "friend_accepted", "matchId", String.valueOf(match.getId()))));
    }

    /** 새 메시지 — 받는 사람은 대화 상대. 내용은 싣지 않는다. */
    public void newMessage(Match match, Long senderId) {
        Long receiverId = match.getRequesterId().equals(senderId) ? match.getAddresseeId() : match.getRequesterId();
        afterCommit(() -> pushSender.send(
                receiverId,
                "새 메시지",
                nicknameOf(senderId) + "님이 메시지를 보냈어요.",
                Map.of("type", "message", "matchId", String.valueOf(match.getId()))));
    }

    /**
     * 트랜잭션이 <b>커밋된 뒤</b> 보낸다. 트랜잭션 밖에서 불렸으면(배치·테스트) 그 자리에서 보낸다.
     *
     * <p>커밋 뒤라 여기서 예외가 나도 원래 요청은 이미 성공했다 — {@code PushSender} 구현이 예외를
     * 삼키므로 로그만 남는다.</p>
     *
     * <p>⚠️ 여기서 부르는 DB 쓰기는 <b>새 트랜잭션이어야 한다</b>. {@code afterCommit} 시점의 트랜잭션은
     * 이미 커밋됐지만 살아 있어서, 그냥 참여하면 그 쓰기가 커밋되지 않는다 —
     * {@code FirebasePushSender.send} 가 {@code REQUIRES_NEW} 인 이유다.</p>
     */
    private void afterCommit(Runnable send) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            send.run();
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                send.run();
            }
        });
    }

    /** 닉네임을 안 정한 사람이 있다 — 발자취·동행 화면과 같은 대체 문구를 쓴다(#71). */
    private String nicknameOf(Long userId) {
        return userRepository.findSummariesByIdIn(java.util.Set.of(userId)).stream()
                .map(UserSummary::nickname)
                .filter(nickname -> nickname != null && !nickname.isBlank())
                .findFirst()
                .orElse("이름 없는 여행자");
    }
}
