package com.fogapp.message;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fogapp.common.ForbiddenException;
import com.fogapp.match.Match;
import com.fogapp.match.MatchService;

/**
 * 친구끼리 메시지(수락된 매칭의 대화).
 *
 * <p>읽기·쓰기 모두 두 조건을 건다.</p>
 * <ol>
 *   <li><b>당사자</b> — 매칭의 요청자·대상자만. 제3자가 매칭 id 만 알아도 남의 대화를 읽으면 안 된다
 *       ({@link MatchService#getForViewer} 가 403 으로 막는다).</li>
 *   <li><b>수락됨</b> — 요청을 보낸 것만으로는 메시지를 못 보낸다. 거절·대기 중인 상대에게
 *       메시지를 밀어넣는 통로가 되지 않게.</li>
 * </ol>
 */
@Service
@Transactional(readOnly = true)
public class MessageService {

    /** 한 번에 내려주는 최대 건수. 대화방을 처음 열 때도, 주기 갱신 때도 같다. */
    static final int PAGE_SIZE = 100;

    private final MessageRepository messageRepository;
    private final MatchService matchService;

    public MessageService(MessageRepository messageRepository, MatchService matchService) {
        this.messageRepository = messageRepository;
        this.matchService = matchService;
    }

    /**
     * @param afterId null 이면 최근 {@link #PAGE_SIZE} 건, 있으면 그 id 이후만(주기 갱신용). 항상 시간순.
     */
    public List<MessageResponse> list(Long viewerId, Long matchId, Long afterId) {
        requireFriends(viewerId, matchId);
        List<Message> messages;
        if (afterId == null) {
            messages = new ArrayList<>(messageRepository.findLatest(matchId, PageRequest.of(0, PAGE_SIZE)));
            Collections.reverse(messages);
        } else {
            messages = messageRepository.findAfter(matchId, afterId, PageRequest.of(0, PAGE_SIZE));
        }
        return messages.stream().map(message -> MessageResponse.from(message, viewerId)).toList();
    }

    @Transactional
    public MessageResponse send(Long senderId, Long matchId, String content) {
        requireFriends(senderId, matchId);
        Message saved = messageRepository.save(new Message(matchId, senderId, content.strip()));
        return MessageResponse.from(saved, senderId);
    }

    private void requireFriends(Long viewerId, Long matchId) {
        Match match = matchService.getForViewer(viewerId, matchId);
        if (!Match.STATUS_ACCEPTED.equals(match.getStatus())) {
            throw new ForbiddenException("친구 요청이 수락된 뒤에 메시지를 주고받을 수 있습니다.");
        }
    }
}
