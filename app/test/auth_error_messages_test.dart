import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/auth_error_messages.dart';

void main() {
  test('알려진 코드는 한국어 문구로 매핑된다', () {
    expect(
      authErrorMessage(FirebaseAuthException(code: 'invalid-credential')),
      '이메일 또는 비밀번호가 올바르지 않습니다.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'invalid-email')),
      '이메일 형식이 올바르지 않습니다.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'email-already-in-use')),
      '이미 가입된 이메일입니다. 로그인해 주세요.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'weak-password')),
      '비밀번호는 6자 이상이어야 합니다.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'network-request-failed')),
      '네트워크 연결을 확인해 주세요.',
    );
    expect(
      authErrorMessage(FirebaseAuthException(code: 'too-many-requests')),
      '시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.',
    );
  });

  test('알려지지 않은 코드는 Firebase 원문을 노출하지 않고 일반 안내로 폴백한다', () {
    final message = authErrorMessage(
      FirebaseAuthException(
        code: 'some-unmapped-code',
        message: 'The supplied auth credential is incorrect, malformed or has expired.',
      ),
    );

    expect(message, '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    expect(message, isNot(contains('supplied')));
  });
}
