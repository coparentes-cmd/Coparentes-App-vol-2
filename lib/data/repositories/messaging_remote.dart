import '../../config/messaging_categories.dart';
import '../../models/models.dart';
import '../api/app_api_client.dart';
import '../serializers/api_serializers.dart';

class MessagingRemote {
  final AppApiClient _apiClient;

  MessagingRemote({required AppApiClient apiClient}) : _apiClient = apiClient;

  bool isNetworkError(Object error) => _apiClient.isNetworkError(error);

  Future<({List<MessageThread> threads, Map<String, Set<String>> tags})>
      fetchThreads() async {
    final payload = await _apiClient.getJson('/threads');
    final threads = (payload['threads'] as List<dynamic>)
        .map(
          (item) => messageThreadFromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    final tags = messageTagsToMap(
      messageTagsFromJsonList(
        payload['messageTags'] as List<dynamic>? ?? const [],
      ),
    );
    return (threads: threads, tags: tags);
  }

  Future<Map<String, Set<String>>> updateMessageTags({
    required String messageId,
    required List<String> tags,
  }) async {
    final payload = await _apiClient.putJson(
      '/threads/messages/$messageId/tags',
      {'tags': tags},
    );
    return messageTagsToMap(
      messageTagsFromJsonList(
        payload['messageTags'] as List<dynamic>? ?? const [],
      ),
    );
  }

  Future<MessageThread> createThread({
    required String subject,
    required String category,
    String? childId,
  }) async {
    final payload = await _apiClient.postJson('/threads', {
      'subject': subject,
      'category': category,
      'childId': childId,
    });
    return messageThreadFromJson(payload);
  }

  Future<MessageThread> createChannel({required String category}) async {
    final payload = await _apiClient.postJson('/threads/channel', {
      'category': category,
    });
    return messageThreadFromJson(payload);
  }

  Future<Map<String, dynamic>> createThreadViaApi({
    required String subject,
    required String category,
    Object? childId,
  }) {
    if (subject == category) {
      if (category == allTabLabel || category == familyCategoryChannel) {
        return _apiClient.postJson('/threads/channel', {
          'category': category,
        });
      }
      if (messagingCategoryChannels.contains(category)) {
        return _apiClient.postJson('/threads/channel', {
          'category': category,
        });
      }
    }

    return _apiClient.postJson('/threads', {
      'subject': subject,
      'category': category,
      'childId': childId,
    });
  }

  Future<MessageThread> sendMessage({
    required String threadId,
    required String content,
    required MessageTone tone,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    return sendMessageWithApiTone(
      threadId: threadId,
      content: content,
      tone: messageToneToApi(tone),
      attachments: attachments,
    );
  }

  Future<MessageThread> sendMessageWithApiTone({
    required String threadId,
    required String content,
    required String tone,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final payload = await _apiClient.postJson(
      '/threads/$threadId/messages',
      {
        'content': content,
        'tone': tone,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
    return messageThreadFromJson(payload);
  }

  Future<Map<String, dynamic>> downloadMessageAttachment({
    required String threadId,
    required String messageId,
    required String attachmentId,
  }) {
    return _apiClient.getJson(
      '/threads/$threadId/messages/$messageId/attachments/$attachmentId',
    );
  }

  Future<MessageThread> markThreadRead(String threadId) async {
    final payload = await _apiClient.postJson('/threads/$threadId/read', {});
    return messageThreadFromJson(payload);
  }
}
