package com.fogapp.match;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.location.MatchLocationVisibilitySync;
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;

/**
 * {@link MatchService#updateStatus}·{@link MatchService#delete}가 위치 공유
 * 동기화(#133)를 상태에 맞게 정확히 호출하는지 — Repository·Firestore 동기화를 전부
 * mock해 순수하게 이 판정 로직만 검증한다.
 */
class MatchServiceLocationSyncTest {

    private static final Long REQUESTER_ID = 1L;
    private static final Long ADDRESSEE_ID = 2L;
    private static final String REQUESTER_UID = "uid-requester";
    private static final String ADDRESSEE_UID = "uid-addressee";

    private MatchRepository matchRepository;
    private UserRepository userRepository;
    private MatchLocationVisibilitySync locationVisibilitySync;
    private MatchService matchService;

    @BeforeEach
    void setUp() {
        matchRepository = mock(MatchRepository.class);
        userRepository = mock(UserRepository.class);
        locationVisibilitySync = mock(MatchLocationVisibilitySync.class);
        matchService = new MatchService(matchRepository, userRepository, new ObjectMapper(), locationVisibilitySync);

        User requester = mock(User.class);
        when(requester.getFirebaseUid()).thenReturn(REQUESTER_UID);
        User addressee = mock(User.class);
        when(addressee.getFirebaseUid()).thenReturn(ADDRESSEE_UID);
        when(userRepository.findById(REQUESTER_ID)).thenReturn(Optional.of(requester));
        when(userRepository.findById(ADDRESSEE_ID)).thenReturn(Optional.of(addressee));
    }

    private Match pendingMatch() {
        Match match = new Match(REQUESTER_ID, ADDRESSEE_ID);
        when(matchRepository.findById(100L)).thenReturn(Optional.of(match));
        return match;
    }

    @Test
    void 수락되면_양쪽_uid로_grant를_호출한다() {
        pendingMatch();

        matchService.updateStatus(ADDRESSEE_ID, 100L, Match.STATUS_ACCEPTED);

        verify(locationVisibilitySync).grant(eq(REQUESTER_UID), eq(ADDRESSEE_UID));
        verify(locationVisibilitySync, never()).revoke(anyString(), anyString());
    }

    @Test
    void 거절되면_양쪽_uid로_revoke를_호출한다() {
        pendingMatch();

        matchService.updateStatus(ADDRESSEE_ID, 100L, Match.STATUS_REJECTED);

        verify(locationVisibilitySync).revoke(eq(REQUESTER_UID), eq(ADDRESSEE_UID));
        verify(locationVisibilitySync, never()).grant(anyString(), anyString());
    }

    @Test
    void 취소_삭제_시에도_revoke를_호출한다() {
        pendingMatch();

        matchService.delete(REQUESTER_ID, 100L);

        verify(locationVisibilitySync).revoke(eq(REQUESTER_UID), eq(ADDRESSEE_UID));
    }
}
