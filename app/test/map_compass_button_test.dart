// 하단 가운데 원 — 나침반이었다가, 스팟에 다가서면 그 자리에서 «!» 로 바뀐다.
//
// ⚠️ «인증 가능» 단계는 고리가 **끝없이** 맥박친다 — 이 파일에서 `pumpAndSettle()` 을
//    쓰면 타임아웃으로 죽는다. `pump()` 로 프레임을 하나씩 넘길 것.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/widgets/map_compass_button.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

MapCompassButton _button(
  MapCompassMode mode, {
  ValueNotifier<double>? bearing,
  VoidCallback? onTap,
}) {
  return MapCompassButton(
    bearing: bearing ?? ValueNotifier<double>(0),
    mode: mode,
    onTap: onTap ?? () {},
  );
}

void main() {
  testWidgets('평소에는 «!» 가 아니라 바늘을 그린다', (tester) async {
    await tester.pumpWidget(_host(_button(MapCompassMode.compass)));
    await tester.pump();

    expect(find.text('!'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('지도를 돌리면 바늘이 반대로 돈다', (tester) async {
    final bearing = ValueNotifier<double>(0);
    await tester.pumpWidget(_host(_button(MapCompassMode.compass, bearing: bearing)));
    await tester.pump();

    double angle() => tester
        .widget<Transform>(find.byKey(const ValueKey('compass-needle')))
        .transform
        .storage[0];

    final north = angle();
    bearing.value = 90;
    await tester.pump();

    expect(angle(), isNot(north), reason: '방위가 바뀌면 바늘도 돌아야 한다');
  });

  testWidgets('근처·인증 단계에서는 «!» 로 바뀐다', (tester) async {
    for (final mode in [MapCompassMode.near, MapCompassMode.verifiable]) {
      await tester.pumpWidget(_host(_button(mode)));
      await tester.pump();
      expect(find.text('!'), findsOneWidget, reason: '$mode');
    }
  });

  // 같은 «!» 라도 흰 바탕의 파란 글자와 파란 바탕의 흰 글자는 멀리서도 다른 것으로 읽힌다.
  testWidgets('근처와 인증 가능은 «!» 의 색이 다르다', (tester) async {
    await tester.pumpWidget(_host(_button(MapCompassMode.near)));
    await tester.pump();
    final near = tester.widget<Text>(find.text('!')).style?.color;

    await tester.pumpWidget(_host(_button(MapCompassMode.verifiable)));
    await tester.pump();
    final verifiable = tester.widget<Text>(find.text('!')).style?.color;

    expect(near, isNot(verifiable));
  });

  testWidgets('누르면 onTap 이 불린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(_button(MapCompassMode.compass, onTap: () => taps++)));
    await tester.pump();

    await tester.tap(find.byType(MapCompassButton));
    expect(taps, 1);
  });
}
