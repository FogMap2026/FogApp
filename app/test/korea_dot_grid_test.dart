// 정복 현황 점 지도([KoreaDotMap])의 격자 계산 — 순수 함수라 위젯 없이 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/korea_dot_grid.dart';

void main() {
  group('바운딩 박스', () {
    test('격자 범위는 폴리곤 전체를 감싼다', () {
      final square = [
        [0.0, 0.0],
        [0.0, 10.0],
        [10.0, 10.0],
        [10.0, 0.0],
        [0.0, 0.0],
      ];
      final grid = buildKoreaDotGrid([square], columns: 10);
      expect(grid.minLat, 0);
      expect(grid.maxLat, 10);
      expect(grid.minLng, 0);
      expect(grid.maxLng, 10);
    });

    test('여러 폴리곤이면 전체를 아우르는 박스가 된다', () {
      final a = [
        [0.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0],
        [1.0, 0.0],
        [0.0, 0.0],
      ];
      final b = [
        [5.0, 5.0],
        [5.0, 6.0],
        [6.0, 6.0],
        [6.0, 5.0],
        [5.0, 5.0],
      ];
      final grid = buildKoreaDotGrid([a, b], columns: 10);
      expect(grid.minLat, 0);
      expect(grid.maxLat, 6);
      expect(grid.minLng, 0);
      expect(grid.maxLng, 6);
    });
  });

  group('점 걸러내기', () {
    test('사각형 폴리곤 안의 격자점만 남는다', () {
      final square = [
        [0.0, 0.0],
        [0.0, 10.0],
        [10.0, 10.0],
        [10.0, 0.0],
        [0.0, 0.0],
      ];
      // columns=4 → 격자선이 0,2.5,5,7.5,10 이라 안쪽 점(2.5·5·7.5)은 경계에서 떨어져
      // 있다. 정확히 경계 위(0, 10)인 점의 판정은 레이 캐스팅 특성상 구현에 따라 갈릴
      // 수 있어 이 테스트에서는 보지 않는다 — 모든 격자점이 바운딩 박스 안인지만 본다.
      final grid = buildKoreaDotGrid([square], columns: 4);
      expect(grid.dots, isNotEmpty);
      for (final dot in grid.dots) {
        expect(dot.lat, inInclusiveRange(0, 10));
        expect(dot.lng, inInclusiveRange(0, 10));
      }
      // 안쪽 한가운데는 반드시 들어온다.
      expect(grid.dots.any((d) => d.lat == 5 && d.lng == 5), isTrue);
    });

    test('폴리곤 밖 영역은 격자에 없다 — L자 모양의 빈 모서리', () {
      // L자: 오른쪽 위 4x4 사분면이 빔.
      final lShape = [
        [0.0, 0.0],
        [0.0, 10.0],
        [5.0, 10.0],
        [5.0, 5.0],
        [10.0, 5.0],
        [10.0, 0.0],
        [0.0, 0.0],
      ];
      final grid = buildKoreaDotGrid([lShape], columns: 20);
      // 빈 사분면 한가운데(8, 8)에 딱 맞는 격자점이 없더라도, 그 근방(7~10, 7~10)에는
      // 점이 하나도 없어야 한다 — L자가 파낸 사분면이다.
      final inEmptyCorner = grid.dots.where((d) => d.lat > 7 && d.lng > 7);
      expect(inEmptyCorner, isEmpty);
      // 반대로 안쪽(2,2)근방에는 점이 있어야 한다.
      final inFilledArea = grid.dots.where((d) => d.lat < 3 && d.lng < 3);
      expect(inFilledArea, isNotEmpty);
    });

    test('폴리곤이 없으면 격자도 비어 있다', () {
      final grid = buildKoreaDotGrid([]);
      expect(grid.dots, isEmpty);
    });
  });

  group('좌표 변환', () {
    test('정규화는 남서쪽을 (0,1) 근처로, 북동쪽을 (1,0) 근처로 보낸다', () {
      final square = [
        [0.0, 0.0],
        [0.0, 10.0],
        [10.0, 10.0],
        [10.0, 0.0],
        [0.0, 0.0],
      ];
      final grid = buildKoreaDotGrid([square], columns: 10);

      final southWest = grid.normalize(0, 0);
      expect(southWest.dx, closeTo(0, 1e-9));
      expect(southWest.dy, closeTo(1, 1e-9));

      final northEast = grid.normalize(10, 10);
      expect(northEast.dx, closeTo(1, 1e-9));
      expect(northEast.dy, closeTo(0, 1e-9));
    });

    test('가로세로 비율은 중위도 보정이 걸려 1:1 위경도보다 좁다', () {
      // 위도 60도 부근에서는 경도 1도가 위도 1도의 절반 거리다(cos 60° = 0.5).
      final square = [
        [55.0, 0.0],
        [55.0, 10.0],
        [65.0, 10.0],
        [65.0, 0.0],
        [55.0, 0.0],
      ];
      final grid = buildKoreaDotGrid([square], columns: 10);
      // lngSpan(10) * cos(60°)(0.5) / latSpan(10) ≈ 0.5
      expect(grid.aspectRatio, closeTo(0.5, 0.05));
    });
  });
}
