import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/theme/app_theme.dart';

/// 디자인 체계(Notion)의 규칙 중 «깨지면 화면에서 바로 티가 나는» 것만 고정한다.
///
/// 색 값 하나하나를 단언하지 않는다 — 톤은 바뀔 수 있다. 대신 역할 사이의 관계를 본다.
void main() {
  final theme = buildAppTheme();

  Widget host(Widget child, {Color background = AppColors.canvasSoft}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        backgroundColor: background,
        body: Center(child: child),
      ),
    );
  }

  Material materialOf(WidgetTester tester, Finder button) {
    return tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first,
    );
  }

  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  group('파랑은 주요 행동에만', () {
    testWidgets('FilledButton 은 파랑이다', (tester) async {
      await tester.pumpWidget(host(FilledButton(onPressed: () {}, child: const Text('인증하기'))));
      expect(materialOf(tester, find.byType(FilledButton)).color, AppColors.primary);
    });

    testWidgets('tonal 버튼은 파랑이 아니다', (tester) async {
      await tester.pumpWidget(host(FilledButton.tonal(onPressed: () {}, child: const Text('동행 요청'))));
      expect(materialOf(tester, find.byType(FilledButton)).color, isNot(AppColors.primary));
    });

    test('표면에 파랑을 섞지 않는다 (surfaceTint 투명)', () {
      // M3 는 elevation 있는 표면에 surfaceTint 를 섞는다 — 흰 카드가 푸르스름해진다.
      expect(theme.colorScheme.surfaceTint, const Color(0x00000000));
    });
  });

  group('보조 버튼이 배경에 녹지 않는다', () {
    testWidgets('흰 카드 안의 tonal 버튼은 흰색이 아니다', (tester) async {
      // 실제로 있었던 일: 보조 버튼 바탕을 흰색으로 두자 동행 추천 카드의
      // 「동행 요청」이 카드와 같은 색이 되어 버튼으로 안 보였다.
      await tester.pumpWidget(
        host(
          Card(child: FilledButton.tonal(onPressed: () {}, child: const Text('동행 요청'))),
          background: AppColors.surface,
        ),
      );
      final button = materialOf(tester, find.byType(FilledButton)).color!;
      expect(button, isNot(theme.cardTheme.color));
    });

    testWidgets('지도 위 버튼 스타일은 흰 알약 + 경계선이고 전역 모양을 잃지 않는다', (tester) async {
      await tester.pumpWidget(
        host(
          FilledButtonTheme(
            data: FilledButtonThemeData(style: mapActionButtonStyle(theme)),
            child: FilledButton.tonal(onPressed: () {}, child: const Text('내 프로필')),
          ),
        ),
      );
      final material = materialOf(tester, find.byType(FilledButton));
      expect(material.color, AppColors.surface);
      // 하위 테마가 전역을 «대체»하면 알약 모양이 사라진다 — 병합했는지 본다.
      expect(material.shape, isA<StadiumBorder>());
      expect((material.shape! as StadiumBorder).side.color, AppColors.hairline);
    });
  });

  group('모양 대비', () {
    testWidgets('주요 버튼은 알약, 입력은 각진 4px', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(onPressed: () {}, child: const Text('로그인')),
              const SizedBox(width: 200, child: TextField()),
            ],
          ),
        ),
      );
      expect(materialOf(tester, find.byType(FilledButton)).shape, isA<StadiumBorder>());
      final border = theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(AppRadii.xs));
    });

    testWidgets('카드는 그림자 대신 경계선', (tester) async {
      await tester.pumpWidget(host(const Card(child: SizedBox(width: 80, height: 40))));
      final material = materialOf(tester, find.byType(Card));
      expect(material.elevation, 0);
      expect((material.shape! as RoundedRectangleBorder).side.color, AppColors.hairline);
    });
  });

  group('읽힌다 (WCAG AA 4.5:1)', () {
    test('본문 잉크 — 종이 바탕·흰 카드 위', () {
      expect(contrast(AppColors.ink, AppColors.canvasSoft), greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.ink, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('설명 글자(inkMuted) — 종이 바탕·흰 카드 위', () {
      expect(contrast(AppColors.inkMuted, AppColors.canvasSoft), greaterThanOrEqualTo(4.5));
      expect(contrast(AppColors.inkMuted, AppColors.surface), greaterThanOrEqualTo(4.5));
    });

    test('파란 버튼 위 흰 글자', () {
      expect(contrast(AppColors.surface, AppColors.primary), greaterThanOrEqualTo(4.5));
    });

    test('보조 버튼 위 잉크', () {
      expect(contrast(AppColors.ink, AppColors.buttonSecondary), greaterThanOrEqualTo(4.5));
    });

    test('오류 배너 글자', () {
      expect(contrast(AppColors.onErrorContainer, AppColors.errorContainer), greaterThanOrEqualTo(4.5));
    });

    test('글자 링크 — 흰 카드·종이 바탕·안내 배너 위', () {
      // 실제로 있었던 일: 채움 버튼과 같은 #0075DE 를 링크에도 쓰자 지도 근접 배너 위
      // 「인증하러 가기」가 3.99:1 로 떨어졌다. 상수가 아니라 «테마가 실제로 내주는» 색을 본다.
      final link = theme.textButtonTheme.style!.foregroundColor!.resolve(<WidgetState>{})!;
      expect(contrast(link, AppColors.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(link, AppColors.canvasSoft), greaterThanOrEqualTo(4.5));
      expect(contrast(link, theme.colorScheme.primaryContainer), greaterThanOrEqualTo(4.5));
    });
  });
}
