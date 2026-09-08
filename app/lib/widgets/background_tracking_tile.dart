import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_tracking_setting.dart';
import '../services/location_service.dart';
import '../services/proximity_notifier.dart';

/// 백그라운드 추적을 켜고 끄는 스위치(#135 To-do "사용자가 끌 수 있는 스위치").
///
/// **켜면 알림 표시줄에 상시 알림이 뜨고 끌 수 없다** — Android 가 백그라운드 위치를
/// 쓰는 앱에 요구하는 것이라 우리가 없앨 수 없다. 그래서 켜기 전에 그 사실을 먼저 말한다.
/// 스위치 밑의 설명이 장식이 아니라 이 이유로 있다.
class BackgroundTrackingTile extends ConsumerStatefulWidget {
  const BackgroundTrackingTile({super.key});

  @override
  ConsumerState<BackgroundTrackingTile> createState() => _BackgroundTrackingTileState();
}

class _BackgroundTrackingTileState extends ConsumerState<BackgroundTrackingTile> {
  /// null이면 아직 저장된 설정을 못 읽은 것 — 그동안 스위치를 잠근다.
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mode = await BackgroundTrackingSetting.load();
    if (mounted) setState(() => _enabled = mode == LocationTrackingMode.always);
  }

  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);

    final mode =
        enabled ? LocationTrackingMode.always : LocationTrackingMode.foregroundOnly;

    // 켤 때만 알림 권한을 묻는다. 거부해도 추적은 되지만 알림이 안 뜨므로 안내한다 —
    // 조용히 켜두면 "켰는데 아무 일도 안 일어난다"가 된다.
    var notificationsAllowed = true;
    if (enabled) {
      final notifier = ref.read(proximityNotifierProvider);
      await notifier.init();
      notificationsAllowed = await notifier.requestPermission();
    }

    await BackgroundTrackingSetting.save(mode);
    await ref.read(locationServiceProvider).setMode(mode);

    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _busy = false;
    });

    if (enabled && !notificationsAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림 권한이 없어 근처 스팟을 알려드릴 수 없어요. 설정에서 알림을 허용해주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _enabled;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('앱을 닫아도 주변 알림 받기', style: theme.textTheme.titleSmall),
                ),
                Switch(
                  value: enabled ?? false,
                  onChanged: (enabled == null || _busy) ? null : _toggle,
                ),
              ],
            ),
            Text(
              '주머니에 넣고 걷는 동안에도 근처 스팟을 알려드려요.\n'
              '켜면 안드로이드 정책상 알림 표시줄에 실행 중 알림이 계속 남고, 배터리를 조금 더 씁니다.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
