// 지도 우상단 «정복률 배터리»(피그마 메인화면) — 단계 판정은 순수 함수라 지도 없이 검증하고,
// 알림으로 «자라는» 것은 위젯 테스트로 폭을 재서 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot.dart';
import 'package:fogapp/services/spot_proximity.dart';
import 'package:fogapp/widgets/conquest_pill.dart';

Spot _spot(int id) => Spot(
      id: id,
      contentId: 'c$id',
      title: '스팟$id',
      lat: 37.5665,
      lng: 126.978,
      unlocked: false,
    );

SpotProximity _proximity(int id, ProximityLevel level) => SpotProximity(
      spot: _spot(id),
      distanceMeters: level == ProximityLevel.verifiable ? 40 : 200,
      level: level,
    );

/// 폭이 «자랄 수 있는» 환경. 실제 배치도 이렇게 남는 폭 전체를 받아 그 안에서 자란다.
Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: Align(alignment: Alignment.topRight, child: child),
      ),
    ),
  );
}

double _pillWidth(WidgetTester tester) {
  // 첫 AnimatedContainer 가 배터리 몸통이다(두 번째는 꼭지).
  return tester.getSize(find.byType(AnimatedContainer).first).width;
}

void main() {
  group('conquestPillModeFor', () {
    test('알릴 스팟이 없으면 정복률을 보여준다', () {
      expect(
        conquestPillModeFor(proximity: null, dismissedSpotId: null),
        ConquestPillMode.progress,
      );
    });

    test('근처 스팟이 있으면 알림으로 바뀐다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(1, ProximityLevel.near),
          dismissedSpotId: null,
        ),
        ConquestPillMode.near,
      );
    });

    test('닫은 스팟의 «근처» 알림은 다시 뜨지 않는다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(1, ProximityLevel.near),
          dismissedSpotId: 1,
        ),
        ConquestPillMode.progress,
      );
    });

    test('다른 스팟이면 닫아 둔 것과 무관하게 알린다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(2, ProximityLevel.near),
          dismissedSpotId: 1,
        ),
        ConquestPillMode.near,
      );
    });

    // 🔴 이게 깨지면 «인증 가능»을 영영 못 보는 사람이 생긴다 — 300m 에서 알림을 한 번 닫고
    //    그대로 걸어 들어가면 인증할 수 있게 돼도 화면이 아무 말을 안 한다.
    test('닫은 스팟이라도 인증 가능해지면 다시 알린다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(1, ProximityLevel.verifiable),
          dismissedSpotId: 1,
        ),
        ConquestPillMode.verifiable,
      );
    });
  });

  group('ConquestPill', () {
    testWidgets('평소에는 정복률 숫자만, 배터리 폭 그대로', (tester) async {
      await tester.pumpWidget(
        _host(
          ConquestPill(
            mode: ConquestPillMode.progress,
            rate: 0.72,
            message: null,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('72'), findsOneWidget);
      expect(_pillWidth(tester), ConquestPill.bodyWidth);
    });

    testWidgets('정복률을 아직 모르면 자리를 «--» 로 채운다', (tester) async {
      await tester.pumpWidget(
        _host(
          ConquestPill(
            mode: ConquestPillMode.progress,
            rate: null,
            message: null,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('알림이 오면 왼쪽으로 자라고 문구가 뜬다', (tester) async {
      await tester.pumpWidget(
        _host(
          ConquestPill(
            mode: ConquestPillMode.near,
            rate: 0.72,
            message: '경복궁 근처 · 약 200m',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('경복궁 근처 · 약 200m'), findsOneWidget);
      // 정복률은 감춘다 — 한 상자가 두 가지를 동시에 말하면 둘 다 안 읽힌다.
      expect(find.text('72'), findsNothing);
      expect(_pillWidth(tester), greaterThan(ConquestPill.bodyWidth));
    });

    // 「인증 가능」이 「근처」보다 길어야 한다 — 같은 폭이면 문구를 읽기 전에는 단계가 구분되지 않는다.
    testWidgets('«인증 가능»은 «근처»보다 길게 자란다', (tester) async {
      await tester.pumpWidget(
        _host(
          ConquestPill(
            mode: ConquestPillMode.near,
            rate: 0.72,
            message: '경복궁 근처',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nearWidth = _pillWidth(tester);

      await tester.pumpWidget(
        _host(
          ConquestPill(
            mode: ConquestPillMode.verifiable,
            rate: 0.72,
            message: '경복궁 인증 가능',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_pillWidth(tester), greaterThan(nearWidth));
    });

    testWidgets('높이는 어느 단계에서나 같다 — 자라는 것은 폭뿐', (tester) async {
      for (final mode in ConquestPillMode.values) {
        await tester.pumpWidget(
          _host(
            ConquestPill(
              mode: mode,
              rate: 0.5,
              message: '문구',
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(AnimatedContainer).first).height,
          ConquestPill.height,
          reason: '$mode 에서 높이가 달라졌다',
        );
      }
    });

    testWidgets('누르면 onTap 이 불린다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ConquestPill(
            mode: ConquestPillMode.progress,
            rate: 0.1,
            message: null,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConquestPill));
      expect(taps, 1);
    });
  });
}
