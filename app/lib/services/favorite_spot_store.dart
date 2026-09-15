import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/spot.dart';

/// 찜한 스팟 — **이 폰에만** 저장한다.
///
/// 찜한 스팟은 지도에 «항상» 뜬다: 내 위치 3km 밖이어도, 📍 로 다른 곳을 보고 있어도.
/// 그래서 id 만이 아니라 좌표·이름까지 통째로 저장한다 — 화면에 없는 스팟을 그리려면
/// 서버를 다시 부르지 않고도 어디 있는지 알아야 한다.
///
/// 서버에 두지 않는 이유: 「나중에 가 볼 곳」 표시는 탐험 기록이 아니라 개인 메모라,
/// 서버 API·마이그레이션을 마감일에 늘리지 않는다. 계정을 옮기면 사라져도 잃는 게 없다.
class FavoriteSpots extends Notifier<List<Spot>> {
  static const _prefsKey = 'spots.favorites';

  @override
  List<Spot> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
      state = list;
    } catch (_) {
      // 저장본이 깨졌으면 빈 목록으로 — 찜은 다시 누르면 된다.
      await prefs.remove(_prefsKey);
    }
  }

  bool isFavorite(int spotId) => state.any((s) => s.id == spotId);

  /// 찜을 켜거나 끈다. 켤 때 저장하는 [spot] 은 그 시점의 정보(잠김 여부 포함)다 —
  /// 나중에 인증해 잠금이 풀리면 지도의 «불러온» 스팟이 앞서므로 표시엔 문제없다.
  Future<void> toggle(Spot spot) async {
    final next = isFavorite(spot.id) ? state.where((s) => s.id != spot.id).toList() : [...state, spot];
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode([for (final s in next) s.toJson()]));
  }
}

final favoriteSpotsProvider = NotifierProvider<FavoriteSpots, List<Spot>>(FavoriteSpots.new);
