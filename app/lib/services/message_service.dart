import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'api_client.dart';

/// 친구 메시지 API 클라이언트. 대화방은 수락된 매칭 한 건이라 경로가 매칭 아래에 있다.
///
/// 수락되지 않은 매칭이거나 내가 당사자가 아니면 서버가 403을 준다.
class MessageService {
  MessageService(this._apiClient);

  final ApiClient _apiClient;

  /// [afterId]가 없으면 최근 100건, 있으면 그 이후만. 항상 시간순(오래된 것 먼저)으로 온다.
  Future<List<ChatMessage>> list({required int matchId, int? afterId}) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/matches/$matchId/messages',
      queryParameters: {if (afterId != null) 'afterId': afterId},
    );
    return (response.data ?? []).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> send({required int matchId, required String content}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/matches/$matchId/messages',
      data: {'content': content},
    );
    return ChatMessage.fromJson(response.data!);
  }
}

final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService(ref.watch(apiClientProvider));
});
