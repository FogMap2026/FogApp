import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/widgets/map_controls.dart';

/// 지도 우하단 컨트롤의 **폭**을 지킨다.
///
/// 이게 깨지면 증상이 컨트롤 자신이 아니라 **다른 버튼에** 나온다. 패널이
/// 화면 폭까지 늘어나 좌하단 액션 버튼들 위를 덮고, 반투명(0.92)이라
/// 아래 버튼이 흐리게 비쳐 보이면서 **탭이 패널에 먹힌다.**
/// 실제로 ⑧ 스토어 스크린샷 1번에 그 상태가 찍혔다.
Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomRight,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

MapControls _controls({VoidCallback? onRecenter = _noop}) {
  return MapControls(onZoomIn: _noop, onZoomOut: _noop, onRecenter: onRecenter, onSpotMode: _noop);
}

void _noop() {}

void main() {
  testWidgets('화면 폭까지 늘어나지 않는다', (tester) async {
    await tester.pumpWidget(_host(_controls()));

    final width = tester.getSize(find.byType(MapControls)).width;
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;

    // Divider 는 고유 폭이 없어 최대 폭까지 늘어난다. Column 의
    // mainAxisSize.min 은 세로만 줄이므로 이걸 막지 못한다.
    expect(
      width,
      lessThan(screenWidth / 2),
      reason: '컨트롤이 화면 절반보다 넓다 — 좌하단 버튼을 덮는다',
    );
    // 40 — 지도를 가리는 면적을 줄이려고 Material 권장(48)보다 작게 잡았다.
    // 값 자체보다 "화면 폭까지 늘어나지 않는다"가 이 테스트의 핵심이다.
    expect(width, 40);
  });

  testWidgets('세 버튼이 다 있고 잘리지 않는다', (tester) async {
    await tester.pumpWidget(_host(_controls()));

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_location_alt), findsOneWidget);
    // 폭을 고정했으므로 버튼이 넘치지 않는지 함께 본다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('네 번째 버튼은 내 주변 → 화면 중심 → 숨김 → 내 주변 순으로 돈다', (tester) async {
    var mode = SpotViewMode.nearby;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MapControls(
            onZoomIn: _noop,
            onZoomOut: _noop,
            onRecenter: _noop,
            onSpotMode: () => setState(() => mode = mode.next),
            spotMode: mode,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.location_on_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pump();
    expect(find.byIcon(Icons.location_off), findsOneWidget);
    await tester.tap(find.byIcon(Icons.location_off));
    await tester.pump();
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  testWidgets('내 위치를 모르면 그 버튼만 비활성', (tester) async {
    await tester.pumpWidget(_host(_controls(onRecenter: null)));

    IconButton buttonFor(IconData icon) {
      return tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
      );
    }

    expect(buttonFor(Icons.my_location).onPressed, isNull);
    expect(buttonFor(Icons.add).onPressed, isNotNull);
  });

  testWidgets('좌하단 버튼을 덮지 않는다', (tester) async {
    // 지금 컨트롤은 상단 우측에 있어 좌하단 버튼과 아예 만나지 않는다.
    // 그래도 이 테스트를 남긴다 — 폭 고정이 풀리면 «어디에 두든» 덮기 때문이다.
    // 실제로 우하단에 있던 시절 스토어 스크린샷에 그 상태가 찍혔다(#185).
    //
    // 아래는 그 시절 배치를 그대로 재현한 것이다.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 64),
                  child: FilledButton(
                    onPressed: _noop,
                    child: Text('발자취 남기기'),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _controls(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final button = tester.getRect(find.byType(FilledButton));
    final controls = tester.getRect(find.byType(MapControls));

    expect(
      button.overlaps(controls),
      isFalse,
      reason: '컨트롤이 발자취 버튼과 겹친다 — 탭이 가로채진다',
    );
  });

  testWidgets('발자취 버튼은 보일 때 채워지고 숨기면 비워진다', (tester) async {
    var hidden = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MapControls(
            onZoomIn: _noop,
            onZoomOut: _noop,
            onRecenter: _noop,
            onSpotMode: _noop,
            onToggleFootprints: () => setState(() => hidden = !hidden),
            footprintsHidden: hidden,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.edit_location_alt), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_location_alt));
    await tester.pump();
    expect(find.byIcon(Icons.edit_location_alt_outlined), findsOneWidget);
  });
}
