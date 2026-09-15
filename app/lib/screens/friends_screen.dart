import 'package:flutter/material.dart';

import 'friends_recommend_tab.dart';
import 'friends_requests_tab.dart';

/// 친구 — 지도 메뉴의 「내 프로필」 바로 아래에서 들어온다.
///
/// 지도 메뉴에 「동행 추천」「내 동행 요청」이 따로 있던 것을 한 화면의 두 탭으로 묶었다.
/// 추천받고(추천 친구) → 요청하고 → 수락을 기다리는(동행 요청) 한 흐름이라 메뉴 버튼 둘보다
/// 탭 둘이 맞고, 지도 메뉴도 한 줄 줄어든다.
///
/// 탭은 옮겨 올 때마다 새로 만들어져 다시 불러온다(`TabBarView` 기본 동작) — 추천 친구에서
/// 요청을 보내고 동행 요청 탭으로 넘어가면 방금 보낸 요청이 바로 보인다.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('친구'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '추천 친구'),
              Tab(text: '동행 요청'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              FriendsRecommendTab(),
              FriendsRequestsTab(),
            ],
          ),
        ),
      ),
    );
  }
}
