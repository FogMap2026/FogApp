// 지도 우하단 근접 아이콘 — «!» 원이 카드로 펼쳐지고, 인증 단계에서는 숨 쉬는 카드를 누르면 스팟 상세로 간다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot.dart';
import 'package:fogapp/services/spot_proximity.dart';
import 'package:fogapp/widgets/proximity_prompt.dart';

const _spot = Spot(id: 7, contentId: 'c7', title: '경복궁', lat: 37.5796, lng: 126.9770, unlocked: false);

SpotProximity _proximity(ProximityLevel level, {double distance = 230}) =>
    SpotProximity(spot: _spot, distanceMeters: distance, level: level);

/// 상위 상태(펼침 여부)를 흉내 내는 호스트 — 실제로는 [MapScreen] 이 들고 있다.
class _Host extends StatefulWidget {
  const _Host({required this.proximity, this.onOpenSpot});

  final SpotProximity proximity;
  final VoidCallback? onOpenSpot;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            width: 320,
            child: Align(
              alignment: Alignment.bottomRight,
              child: ProximityPrompt(
                proximity: widget.proximity,
                expanded: expanded,
                onExpand: () => setState(() => expanded = true),
                onCollapse: () => setState(() => expanded = false),
                onOpenSpot: widget.onOpenSpot ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('근처 — 처음엔 «!» 원만 보이고, 누르면 카드로 펼쳐지며, 닫으면 다시 원이다', (tester) async {
    await tester.pumpWidget(_Host(proximity: _proximity(ProximityLevel.near)));
    await tester.pumpAndSettle();

    final circle = tester.getSize(find.byType(AnimatedContainer));
    expect(circle.width, 52);
    expect(circle.height, 52);

    await tester.tap(find.text('!'));
    await tester.pumpAndSettle();

    final card = tester.getSize(find.byType(AnimatedContainer));
    expect(card.width, greaterThan(250), reason: '원이 옆으로 늘어나 카드가 된다');
    expect(find.text('경복궁 근처예요'), findsOneWidget);
    expect(find.textContaining('약 230m'), findsOneWidget);
    expect(find.textContaining('100m 안으로 가면 인증할 수 있어요'), findsOneWidget);

    await tester.tap(find.byTooltip('접기'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AnimatedContainer)).width, 52);
  });

  testWidgets('근처 단계에는 인증 버튼이 없다 — 100m 밖에서 인증하면 서버가 거절한다', (tester) async {
    var opened = false;
    await tester.pumpWidget(_Host(proximity: _proximity(ProximityLevel.near), onOpenSpot: () => opened = true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('!'));
    await tester.pumpAndSettle();

    expect(find.text('경복궁 인증 가능'), findsNothing);
    expect(opened, isFalse);
  });

  testWidgets('인증 가능 — 「경복궁 인증 가능」처럼 스팟 이름이 뜨고, 카메라 없이 카드를 누르면 스팟 상세로 간다', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _Host(proximity: _proximity(ProximityLevel.verifiable, distance: 60), onOpenSpot: () => opened++),
    );
    // 맥박 애니메이션이 계속 돌아 pumpAndSettle 은 끝나지 않는다 — 등장 전환 시간만큼만 흘린다.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('경복궁 인증 가능'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);
    expect(find.text('!'), findsNothing);

    await tester.tap(find.text('경복궁 인증 가능'));
    expect(opened, 1);
  });
}
