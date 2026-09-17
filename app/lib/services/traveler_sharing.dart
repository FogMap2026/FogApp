import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 내 위치 공유(#133) 켜짐/꺼짐 — 세션 동안만 산다.
///
/// 스위치는 설정 화면에(#237 로 프로필에서 옮겨졌다), 실제 게시(60분마다 좌표 → 서버가 스팟
/// id 로 환산)는 지도 화면이 한다 — 내 위치를 아는 곳이 지도라서. 둘을 이 provider 가 잇는다:
/// 설정에서 값을 바꾸면 지도가 `ref.listen` 으로 받아 타이머를 켜고 끈다.
///
/// **기본값 꺼짐**이고 저장하지 않는다 — 위치정보 신고 접수본의 opt-in 요건. 앱을 다시
/// 켜면 꺼진 상태로 시작하고, 서버에 남은 행은 **마지막 갱신 후 2시간**(`TravelerService.MAX_AGE_MINUTES`)
/// 이 지나면 조회에서 빠진다(30분은 «보이기 시작하는» 지연이다 — 방침 4장도 2시간으로 적혀 있다).
class TravelerSharing extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool enabled) => state = enabled;
}

final travelerSharingProvider = NotifierProvider<TravelerSharing, bool>(TravelerSharing.new);
