import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 탐험 현황의 즐겨찾기 시/도 — **이 폰에만** 저장한다.
///
/// 서버에 두지 않는 이유: 「어느 지역을 먼저 보고 싶은가」는 화면 정렬 취향이지 탐험
/// 기록이 아니다. 계정을 옮기면 사라져도 잃는 게 없고, 서버 API·마이그레이션을
/// 마감일에 늘리지 않는다.
///
/// 키는 [ConquestSido] 의 정규화된 시/도 이름(또는 이름이 없으면 코드)이다 — 관광공사
/// 코드가 아니라 이름을 쓰는 것은, 통합된 시/도(코드 둘)가 배지 하나이기 때문이다.
class FavoriteSidoStore {
  static const _prefsKey = 'conquest.favoriteSidos';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const []).toSet();
  }

  /// [key] 를 켜거나 끈 뒤 새 집합을 돌려준다.
  Future<Set<String>> toggle(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    if (!current.remove(key)) current.add(key);
    await prefs.setStringList(_prefsKey, current.toList());
    return current;
  }
}

final favoriteSidoStoreProvider = Provider<FavoriteSidoStore>((ref) => FavoriteSidoStore());
