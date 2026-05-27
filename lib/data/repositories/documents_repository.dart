import '../../models/models.dart';
import '../api/app_api_client.dart';
import '../local/offline_store.dart';
import '../serializers/document_serializers.dart';

class DocumentsRepository {
  final AppApiClient _apiClient;
  final OfflineStore _offlineStore;

  DocumentsRepository({
    required AppApiClient apiClient,
    required OfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<List<FamilyDocument>> getDocuments() async {
    await syncPendingActions();

    try {
      final payload = await _apiClient.getJson('/documents');
      final documents = (payload['documents'] as List<dynamic>)
          .map(
            (item) => familyDocumentFromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      await _saveDocuments(documents);
      return documents;
    } catch (error) {
      final cached = _getCachedDocuments();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<FamilyDocument> createDocument({
    required String title,
    required String category,
    String? childId,
    String? fileName,
    String? mimeType,
    String? fileUrl,
    String? contentBase64,
  }) async {
    try {
      final payload = await _apiClient.postJson('/documents', {
        'title': title,
        'category': category,
        'childId': childId,
        'fileName': fileName,
        'mimeType': mimeType,
        'fileUrl': fileUrl,
        'contentBase64': contentBase64,
      });
      final created = familyDocumentFromJson(payload);
      await _upsertDocument(created);
      return created;
    } catch (error) {
      if (!_apiClient.isNetworkError(error)) {
        rethrow;
      }

      final now = DateTime.now();
      final local = FamilyDocument(
        id: 'local_doc_${now.microsecondsSinceEpoch}',
        title: title,
        category: category,
        childId: childId,
        fileName: fileName,
        mimeType: mimeType,
        fileUrl: fileUrl,
        hasFile: fileUrl != null || contentBase64 != null,
        createdAt: now,
        updatedAt: now,
      );
      await _upsertDocument(local);
      await _offlineStore.appendPendingAction({
        'type': 'documents.createDocument',
        'createdAt': now.toIso8601String(),
        'payload': {
          'clientDocumentId': local.id,
          'title': title,
          'category': category,
          'childId': childId,
          'fileName': fileName,
          'mimeType': mimeType,
          'fileUrl': fileUrl,
          'contentBase64': contentBase64,
        },
      });
      return local;
    }
  }

  Future<Map<String, dynamic>> downloadDocument(String documentId) async {
    return _apiClient.getJson('/documents/$documentId/download');
  }

  Future<void> syncPendingActions() async {
    final actions = _offlineStore.getPendingActions();
    if (actions.isEmpty) {
      return;
    }

    final cachedDocuments = _getCachedDocuments();
    final rewrittenQueue = <Map<String, dynamic>>[];
    var networkFailed = false;

    for (final action in actions) {
      final type = action['type'] as String? ?? '';
      if (!type.startsWith('documents.')) {
        rewrittenQueue.add(action);
        continue;
      }

      if (networkFailed) {
        rewrittenQueue.add(action);
        continue;
      }

      try {
        switch (type) {
          case 'documents.createDocument':
            final payload = Map<String, dynamic>.from(action['payload'] as Map);
            final response = await _apiClient.postJson('/documents', {
              'title': payload['title'],
              'category': payload['category'],
              'childId': payload['childId'],
              'fileName': payload['fileName'],
              'mimeType': payload['mimeType'],
              'fileUrl': payload['fileUrl'],
              'contentBase64': payload['contentBase64'],
            });
            final created = familyDocumentFromJson(response);
            final clientDocumentId = payload['clientDocumentId'] as String;
            _replaceDocumentId(cachedDocuments, clientDocumentId, created);
            break;
          default:
            rewrittenQueue.add(action);
        }
      } on ApiException catch (error) {
        if (error.statusCode >= 500) {
          rethrow;
        }
      } catch (_) {
        networkFailed = true;
        rewrittenQueue.add(action);
      }
    }

    await _saveDocuments(cachedDocuments);
    await _offlineStore.savePendingActions(rewrittenQueue);
  }

  List<FamilyDocument> _getCachedDocuments() {
    return _offlineStore
        .getDocuments()
        .map(familyDocumentFromJson)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _saveDocuments(List<FamilyDocument> documents) {
    return _offlineStore.saveDocuments(
      documents.map(familyDocumentToJson).toList(),
    );
  }

  Future<void> _upsertDocument(FamilyDocument document) async {
    final cached = _getCachedDocuments();
    final index = cached.indexWhere((item) => item.id == document.id);
    if (index >= 0) {
      cached[index] = document;
    } else {
      cached.insert(0, document);
    }
    cached.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveDocuments(cached);
  }

  void _replaceDocumentId(
    List<FamilyDocument> documents,
    String oldId,
    FamilyDocument replacement,
  ) {
    final index = documents.indexWhere((document) => document.id == oldId);
    if (index >= 0) {
      documents[index] = replacement;
    } else {
      documents.insert(0, replacement);
    }
  }
}
