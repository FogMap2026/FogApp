package com.fogapp.location;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.concurrent.ExecutionException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.google.api.core.ApiFuture;
import com.google.api.core.ApiFutures;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.SetOptions;
import com.google.cloud.firestore.WriteBatch;
import com.google.cloud.firestore.WriteResult;

/**
 * grant/revoke가 올바른 두 문서에 배치로 반영되는지, 그리고 <b>쓰기가 실패해도 예외를
 * 던지지 않는지</b>(클래스 계약 — 위치 공유 실패가 매칭 자체를 막으면 안 된다)를 검증한다.
 */
class FirestoreMatchLocationVisibilitySyncTest {

    private static final String UID_A = "uid-a";
    private static final String UID_B = "uid-b";

    private Firestore firestore;
    private WriteBatch batch;
    private DocumentReference docA;
    private DocumentReference docB;
    private FirestoreMatchLocationVisibilitySync sync;

    @BeforeEach
    void setUp() {
        firestore = mock(Firestore.class);
        batch = mock(WriteBatch.class);
        docA = mock(DocumentReference.class);
        docB = mock(DocumentReference.class);
        CollectionReference collection = mock(CollectionReference.class);

        when(firestore.collection("locations")).thenReturn(collection);
        when(collection.document(UID_A)).thenReturn(docA);
        when(collection.document(UID_B)).thenReturn(docB);
        when(firestore.batch()).thenReturn(batch);
        when(batch.set(any(DocumentReference.class), anyMap(), any(SetOptions.class))).thenReturn(batch);

        sync = new FirestoreMatchLocationVisibilitySync(firestore);
    }

    @Test
    void grant는_양쪽_문서를_하나의_배치로_갱신한다() throws Exception {
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.<WriteResult>of()));

        sync.grant(UID_A, UID_B);

        // 두 문서(A, B) 각각에 set이 한 번씩, 총 두 번 — 한쪽만 반영되는 일이 없도록
        // 같은 batch 안에서 처리됐는지가 핵심이다.
        verify(batch, times(1)).set(eq(docA), anyMap(), any(SetOptions.class));
        verify(batch, times(1)).set(eq(docB), anyMap(), any(SetOptions.class));
        verify(batch, times(1)).commit();
    }

    @Test
    void revoke도_양쪽_문서를_하나의_배치로_갱신한다() throws Exception {
        when(batch.commit()).thenReturn(ApiFutures.immediateFuture(List.<WriteResult>of()));

        sync.revoke(UID_A, UID_B);

        verify(batch, times(1)).set(eq(docA), anyMap(), any(SetOptions.class));
        verify(batch, times(1)).set(eq(docB), anyMap(), any(SetOptions.class));
        verify(batch, times(1)).commit();
    }

    @Test
    @SuppressWarnings("unchecked")
    void 쓰기가_실패해도_예외를_던지지_않는다() throws Exception {
        // 위치 공유는 매칭의 부가 기능이라, Firestore 장애가 매칭 수락/취소 자체를
        // 실패시키면 안 된다 — FirestoreMatchLocationVisibilitySync 클래스 문서 참고.
        ApiFuture<List<WriteResult>> failing = mock(ApiFuture.class);
        when(failing.get()).thenThrow(new ExecutionException("firestore unavailable", new RuntimeException()));
        when(batch.commit()).thenReturn(failing);

        assertThatCode(() -> sync.grant(UID_A, UID_B)).doesNotThrowAnyException();
        assertThatCode(() -> sync.revoke(UID_A, UID_B)).doesNotThrowAnyException();
    }
}
