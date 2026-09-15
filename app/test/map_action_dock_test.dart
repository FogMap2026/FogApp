// 지도 하단 원 셋 + ☰ 메뉴(피그마 메인화면).
//
// 이 화면에서 **상시로 보이는 버튼은 셋뿐**이라는 것이 이 배치의 전부다 — 예전에는 좌하단
// 열과 우측 패널을 합쳐 일곱 개가 지도를 덮었고, 늘어날 때마다 네이버 로고와 서로를
// 밀어냈다(#64·#187·#190·#194). 그 수가 다시 늘어나면 여기서 먼저 깨진다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/widgets/map_action_dock.dart';
import 'package:fogapp/widgets/map_compass_button.dart';

final _bearing = ValueNotifier<double>(0);

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        height: 640,
        child: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
}

MapActionDock _dock({
  bool menuOpen = false,
  List<MapMenuEntry>? entries,
  int? quota,
  bool busy = false,
  VoidCallback? onFootprint,
  VoidCallback? onToggleMenu,
}) {
  return MapActionDock(
    onFootprint: onFootprint ?? () {},
    footprintQuota: quota,
    footprintBusy: busy,
    bearing: _bearing,
    compassMode: MapCompassMode.compass,
    onCompass: () {},
    menuOpen: menuOpen,
    onToggleMenu: onToggleMenu ?? () {},
    menuEntries: entries ?? const [],
  );
}

void main() {
  testWidgets('접혀 있으면 메뉴 항목이 하나도 안 보인다', (tester) async {
    await tester.pumpWidget(
      _host(
        _dock(
          entries: [
            MapMenuEntry(icon: Icons.settings_outlined, label: '설정', onTap: () {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsNothing);
    expect(find.byType(MapCompassButton), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('펼치면 준 순서 그대로 ☰ 위에 쌓인다', (tester) async {
    await tester.pumpWidget(
      _host(
        _dock(
          menuOpen: true,
          entries: [
            MapMenuEntry(icon: Icons.travel_explore, label: '멀리 있는 스팟 보기', onTap: () {}),
            MapMenuEntry(icon: Icons.directions_walk, label: '다른 사람 발자취', onTap: () {}),
            MapMenuEntry(icon: Icons.settings_outlined, label: '설정', onTap: () {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getCenter(find.text('멀리 있는 스팟 보기')).dy;
    final last = tester.getCenter(find.text('설정')).dy;
    final toggle = tester.getCenter(find.byIcon(Icons.close)).dy;

    expect(first, lessThan(last), reason: '첫 항목이 맨 위에 서야 한다');
    expect(last, lessThan(toggle), reason: '메뉴는 ☰ «위로» 자란다');
  });

  testWidgets('☰ 는 접든 펼치든 같은 자리에 있는다', (tester) async {
    final entries = [
      MapMenuEntry(icon: Icons.settings_outlined, label: '설정', onTap: () {}),
    ];
    await tester.pumpWidget(_host(_dock(entries: entries)));
    await tester.pumpAndSettle();
    final closed = tester.getCenter(find.byIcon(Icons.menu));

    await tester.pumpWidget(_host(_dock(menuOpen: true, entries: entries)));
    await tester.pumpAndSettle();
    final opened = tester.getCenter(find.byIcon(Icons.close));

    expect(opened, closed);
  });

  testWidgets('토글이 켜져 있으면 강조색으로 그린다', (tester) async {
    await tester.pumpWidget(
      _host(
        _dock(
          menuOpen: true,
          entries: [
            MapMenuEntry(
              icon: Icons.directions_walk,
              label: '다른 사람 발자취',
              active: true,
              onTap: () {},
            ),
            MapMenuEntry(
              icon: Icons.travel_explore,
              label: '멀리 있는 스팟 보기',
              active: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final on = tester.widget<Icon>(find.byIcon(Icons.directions_walk));
    final off = tester.widget<Icon>(find.byIcon(Icons.travel_explore));
    expect(on.color, isNot(off.color), reason: '켜짐/꺼짐이 색으로 구분돼야 한다');
  });

  testWidgets('남은 발자취 횟수를 뱃지로 띄운다', (tester) async {
    await tester.pumpWidget(_host(_dock(quota: 3)));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    // 아직 못 받아왔으면(null) 아무 숫자도 띄우지 않는다 — 「0회 남음」으로 오해된다.
    await tester.pumpWidget(_host(_dock()));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);
  });

  testWidgets('위치를 재는 중에는 발자취 버튼이 스피너가 된다', (tester) async {
    await tester.pumpWidget(_host(_dock(busy: true)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('☰ 를 누르면 onToggleMenu 가 불린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(_dock(onToggleMenu: () => taps++)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    expect(taps, 1);
  });
}
