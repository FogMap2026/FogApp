import 'package:flutter/material.dart';

import 'friends_list_tab.dart';
import 'friends_recommend_tab.dart';
import 'friends_requests_tab.dart';

/// 친구 — 지도 메뉴의 「내 프로필」 바로 아래에서 들어온다.
///
/// 세 탭이 한 흐름이다: 「추천 친구」에서 친구 요청을 보내고 → 「친구 요청」에서 수락을 기다리거나
/// 받은 요청을 수락하고 → 수락되면 「친구」에 떠서 메시지를 주고받는다. 친구는 따로 저장하지 않고
/// **수락된 매칭**이 곧 친구다.
///
/// 탭은 옮겨 올 때마다 새로 만들어져 다시 불러온다(`TabBarView` 기본 동작) — 요청을 수락하고
/// 「친구」 탭으로 넘어가면 방금 맺은 친구가 바로 보인다.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('친구'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '친구'),
              Tab(text: '친구 요청'),
              Tab(text: '추천 친구'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              FriendsListTab(),
              FriendsRequestsTab(),
              FriendsRecommendTab(),
            ],
          ),
        ),
      ),
    );
  }
}
