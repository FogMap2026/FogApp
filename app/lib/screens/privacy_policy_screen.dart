import 'package:flutter/material.dart';

/// 개인정보처리방침 전문(#152, #153).
///
/// `docs/store/privacy-policy.html`(원스토어 등록용 공개 페이지)과 **내용이 같아야
/// 한다** — 동의 화면·앱 내 열람·스토어 등록 페이지 세 곳의 문구가 어긋나면 안 된다는
/// 이슈 #152의 요구사항이다. 웹뷰나 외부 브라우저 대신 텍스트로 그대로 옮긴 이유는
/// 새 패키지 의존성(`url_launcher`/`webview_flutter`) 없이 마감 전에 안전하게
/// 넣기 위해서다 — 공개 URL은 스토어 등록 화면에 별도로 입력된다(#153).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보처리방침')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('FogApp 개인정보처리방침', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '시행일: 2026년 9월 14일',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Text(
              'FogApp(이하 "서비스")은 이용자의 개인정보를 소중히 다루며, '
              '「개인정보 보호법」 및 「위치정보의 보호 및 이용 등에 관한 법률」을 준수합니다. '
              '본 방침은 서비스가 어떤 정보를 어떤 목적으로 수집·이용하며 어떻게 보호하는지를 설명합니다.',
            ),
            const _Section(
              title: '1. 수집하는 개인정보 항목',
              body:
                  '• 계정 — 이메일 주소, 인증 식별자(Firebase UID) — 회원가입·로그인 시\n'
                  '• 프로필(선택) — 닉네임, 프로필 이미지 — 이용자가 직접 입력할 때\n'
                  '• 위치정보 — 단말의 위도·경도 — 지도 이용 중, 방문 인증 시, 발자취 작성 시\n'
                  '• 사진 — 방문 인증 사진, 발자취에 첨부한 사진 — 이용자가 촬영·첨부할 때\n'
                  '• 이용기록 — 방문 인증 이력(장소·시각·좌표), 작성한 글귀, 좋아요, 동행 요청·수락 이력\n'
                  '• 여행 성향 — 성향 테스트 응답 결과 및 점수 — 이용자가 테스트를 완료할 때\n\n'
                  '주민등록번호, 연락처, 결제 정보는 수집하지 않습니다. 서비스는 무료이며 결제 기능이 없습니다.',
            ),
            const _Section(
              title: '2. 개인정보의 이용 목적',
              body:
                  '• 계정 정보 — 회원 식별, 로그인 유지, 본인의 기록 연결\n'
                  '• 위치정보 — 주변 관광 스팟 조회, 방문 인증 반경(100m) 판정, 발자취를 남긴 지점 기록, '
                  '지역별 정복률 계산\n'
                  '• 사진 — 실제 방문 사실의 인증, 발자취 내용 표시\n'
                  '• 이용기록 — 안개 해제 상태 유지, 정복률 산출, 다른 이용자에게 발자취·좋아요 수 표시\n'
                  '• 여행 성향 — 성향이 유사한 동행 추천',
            ),
            const _Section(
              title: '3. 위치정보의 처리',
              body:
                  '서비스의 핵심 기능은 이용자가 실제로 그 장소에 도달했는지에 기반합니다. '
                  '이를 위해 다음과 같이 위치정보를 처리합니다.\n\n'
                  '• 위치정보는 기본적으로 앱이 실행 중일 때만 수집합니다.\n'
                  '• 이용자가 「백그라운드 위치 추적」을 직접 켠 경우에 한해, 앱을 보고 있지 않을 때에도 '
                  '위치를 수집합니다. 이 설정은 기본값이 꺼짐이며, 켜져 있는 동안에는 안드로이드 알림이 '
                  '상시 표시됩니다. 프로필 화면에서 언제든 다시 끌 수 있습니다.\n'
                  '• 주변 관광 스팟·발자취를 조회하기 위해 현재 위치 좌표가 서버로 전송됩니다. '
                  '이 좌표는 조회에만 사용되고 그 자체로는 서버에 저장되지 않습니다.\n'
                  '• 서버에 저장되는 좌표는 이용자가 직접 수행한 행위의 결과에 한정됩니다 — 방문 인증을 '
                  '한 지점, 발자취를 남긴 지점.\n'
                  '• 이용자는 단말의 설정에서 위치 권한을 언제든 철회할 수 있습니다. 다만 권한이 없으면 '
                  '안개 해제·방문 인증 등 핵심 기능을 이용할 수 없습니다.',
            ),
            const _Section(
              title: '4. 개인정보의 보유 및 이용 기간',
              body:
                  '• 서비스는 현재 앱 내 회원 탈퇴 기능을 제공하지 않습니다. 탈퇴 및 개인정보 파기를 '
                  '원하시면 11장의 연락처로 요청해 주시기 바라며, 요청을 확인한 즉시 계정과 관련 정보'
                  '(방문 인증 기록·사진, 발자취, 성향 결과)를 파기합니다.\n'
                  '• 이용자가 작성한 발자취는 앱에서 직접 삭제할 수 있으며, 삭제 시 즉시 파기됩니다.\n'
                  '• 관계 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.',
            ),
            const _Section(
              title: '5. 개인정보의 제3자 제공',
              body:
                  '서비스는 이용자의 개인정보를 제3자에게 제공하지 않습니다.\n\n'
                  '다만 다음 정보는 서비스의 성격상 다른 이용자에게 공개됩니다. 공개를 원하지 않으면 '
                  '해당 기능을 이용하지 않거나 작성한 내용을 삭제할 수 있습니다.\n\n'
                  '• 작성한 발자취의 내용·작성 시각·작성 지점과 닉네임·프로필 이미지\n'
                  '• 동행 추천 대상이 되었을 때의 닉네임·여행 성향 유형',
            ),
            const _Section(
              title: '6. 개인정보 처리의 위탁',
              body:
                  '• Google LLC(Firebase Authentication) — 회원 인증 및 계정 관리\n\n'
                  '관광 스팟 정보는 한국관광공사 OpenAPI에서 받아옵니다. 이 과정에서 이용자의 '
                  '개인정보가 외부로 전송되지는 않습니다.',
            ),
            const _Section(
              title: '7. 이용자의 권리와 행사 방법',
              body:
                  '이용자는 언제든지 다음 권리를 행사할 수 있습니다.\n\n'
                  '• 개인정보 열람·정정 — 앱의 프로필 화면에서 직접 확인·수정\n'
                  '• 작성한 발자취의 수정·삭제 — 앱의 내 발자취 화면에서 직접 수행\n'
                  '• 위치 권한 철회 — 단말 설정에서 언제든 가능\n'
                  '• 회원 탈퇴 및 개인정보 삭제 요청 — 11장의 연락처로 요청. 앱 내 탈퇴 기능이 '
                  '아직 없어 연락을 통해 처리합니다',
            ),
            const _Section(
              title: '8. 개인정보의 파기 절차 및 방법',
              body:
                  '• 전자적 파일 형태의 정보는 복구할 수 없는 방법으로 영구 삭제합니다.\n'
                  '• 저장된 사진 파일은 서버 저장소에서 삭제하며, 참조가 끊긴 사진은 정기적으로 정리합니다.',
            ),
            const _Section(
              title: '9. 개인정보의 안전성 확보 조치',
              body:
                  '• 모든 통신 구간에 HTTPS 암호화를 적용합니다.\n'
                  '• 비밀번호는 서비스가 직접 보관하지 않으며 Firebase Authentication이 관리합니다.\n'
                  '• 모든 데이터 조회·수정 요청은 인증 토큰을 검증한 뒤 본인의 데이터에만 접근하도록 '
                  '제한합니다.\n'
                  '• 개인정보에 접근할 수 있는 인원을 최소한으로 제한합니다.',
            ),
            const _Section(
              title: '10. 만 14세 미만 아동의 개인정보',
              body: '서비스는 만 14세 미만 아동의 회원가입을 받지 않으며, 해당 연령의 개인정보를 '
                  '의도적으로 수집하지 않습니다.',
            ),
            const _Section(
              title: '11. 개인정보 보호책임자 및 문의처',
              body:
                  '개인정보 보호책임자: FogApp 팀\n'
                  '문의 이메일: skunhee1201@naver.com\n\n'
                  '개인정보 침해에 대한 상담이 필요한 경우 아래 기관에 문의하실 수 있습니다.\n\n'
                  '• 개인정보침해신고센터 (privacy.kisa.or.kr / 국번없이 118)\n'
                  '• 개인정보 분쟁조정위원회 (kopico.go.kr / 1833-6972)\n'
                  '• 대검찰청 사이버수사과 (spo.go.kr / 국번없이 1301)\n'
                  '• 경찰청 사이버수사국 (ecrm.police.go.kr / 국번없이 182)',
            ),
            const _Section(
              title: '12. 방침의 변경',
              body: '본 방침을 변경할 경우 시행일 및 변경 내용을 앱 또는 공개 페이지에 공지합니다.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const Divider(height: 16),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
