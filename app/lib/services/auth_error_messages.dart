import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// [FirebaseAuthException.code]를 한국어 안내 문구로 변환한다(#65).
///
/// `e.message`는 Firebase SDK가 주는 영어 원문이라 사용자에게 그대로 보여주지 않는다 —
/// 안정적인 식별자인 `e.code`로 분기한다. 매핑되지 않은 코드는 원문을 노출하지 않고
/// 일반 안내로 폴백하되, 디버그 빌드에서는 로그로 남겨 추적할 수 있게 한다.
///
/// Firebase는 2023년부터 "비밀번호 틀림"과 "계정 없음"을 구분하지 않고 둘 다
/// `invalid-credential`로 돌려준다(계정 존재 여부를 알아내는 공격을 막기 위함) —
/// 그래서 이 매핑도 둘을 구분하지 않는다.
String authErrorMessage(FirebaseAuthException e) {
  if (kDebugMode) {
    debugPrint('[Auth] ${e.code}: ${e.message}');
  }

  switch (e.code) {
    case 'invalid-credential':
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    case 'invalid-email':
      return '이메일 형식이 올바르지 않습니다.';
    case 'email-already-in-use':
      return '이미 가입된 이메일입니다. 로그인해 주세요.';
    case 'weak-password':
      return '비밀번호는 6자 이상이어야 합니다.';
    case 'network-request-failed':
      return '네트워크 연결을 확인해 주세요.';
    case 'too-many-requests':
      return '시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
    default:
      return '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  }
}
