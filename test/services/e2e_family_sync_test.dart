import 'dart:typed_data';

import 'package:coparentes/config/messaging_categories.dart';
import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/data/local/offline_store.dart';
import 'package:coparentes/data/repositories/messaging_repository.dart';
import 'package:coparentes/models/models.dart';
import 'package:coparentes/providers/messaging_provider.dart';
import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_key_storage_service.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:coparentes/utils/secure_storage_options.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records GETs/POSTs and returns canned JSON (or throws).
class _RecordingApiClient extends AppApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://fake.local/api');

  final List<String> gets = <String>[];
  final List<({String path, Map<String, dynamic> body})> posts =
      <({String path, Map<String, dynamic> body})>[];

  Future<Map<String, dynamic>> Function(String path)? onGet;
  Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic> body,
  )? onPost;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    gets.add(path);
    final handler = onGet;
    if (handler == null) {
      throw StateError('unexpected GET $path');
    }
    return handler(path);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    Map<String, String>? extraHeaders,
  }) async {
    posts.add((path: path, body: Map<String, dynamic>.from(body)));
    final handler = onPost;
    if (handler == null) {
      return <String, dynamic>{'ok': true};
    }
    return handler(path, body);
  }
}

class _CountingSyncE2e extends E2eSessionService {
  _CountingSyncE2e() : super(apiClient: AppApiClient(baseUrl: 'http://fake'));

  final List<({String threadId, String childUserId})> syncCalls =
      <({String threadId, String childUserId})>[];

  @override
  Future<void> syncFamilyThreadKeyIfNeeded({
    required String threadId,
    required String childUserId,
  }) async {
    syncCalls.add((threadId: threadId, childUserId: childUserId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBacking;
  late E2eCryptoService crypto;
  late E2eKeyStorageService keyStorage;
  late _RecordingApiClient api;
  late E2eSessionService e2e;

  setUp(() {
    secureBacking = <String, String>{};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(secureBacking);
    crypto = E2eCryptoService();
    keyStorage = E2eKeyStorageService(secureStorage: buildSecureStorage());
    api = _RecordingApiClient();
    e2e = E2eSessionService(
      apiClient: api,
      crypto: crypto,
      keyStorage: keyStorage,
    );
  });

  Future<
      ({
        SimpleKeyPairData parent,
        SimpleKeyPairData? child,
        String childPublicKey,
        Uint8List threadKey,
      })> _prepareParentWithChildKeyAndMine({
    required String threadId,
    required String childUserId,
    bool childHasPublicKey = true,
    Object? postError,
  }) async {
    final parentPair = await (await crypto.generateKeyPair()).extract();
    await keyStorage.storeUnlockedKeyPair(parentPair);

    final threadKey = crypto.generateThreadKey();
    final sealedMine = await crypto.sealForRecipient(
      plaintext: threadKey,
      recipientPublicKey: await parentPair.extractPublicKey(),
    );

    String? childPublicB64;
    SimpleKeyPairData? childPair;
    if (childHasPublicKey) {
      childPair = await (await crypto.generateKeyPair()).extract();
      childPublicB64 =
          crypto.encodePublicKey(await childPair.extractPublicKey());
    }

    api.onGet = (path) async {
      if (path == '/user/$childUserId/public-key') {
        return <String, dynamic>{'publicKey': childPublicB64};
      }
      if (path == '/threads/$threadId/keys/mine') {
        return <String, dynamic>{'encryptedKey': sealedMine};
      }
      throw StateError('unexpected GET $path');
    };

    api.onPost = (path, body) async {
      if (postError != null) {
        throw postError;
      }
      return <String, dynamic>{'ok': true};
    };

    return (
      parent: parentPair,
      child: childPair,
      childPublicKey: childPublicB64 ?? '',
      threadKey: threadKey,
    );
  }

  group('syncFamilyThreadKeyIfNeeded', () {
    test('success: POST with correct body and child enters session cache',
        () async {
      const threadId = 'thread-family-1';
      const childUserId = 'child-user-1';
      final prepared = await _prepareParentWithChildKeyAndMine(
        threadId: threadId,
        childUserId: childUserId,
      );

      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );

      expect(api.posts, hasLength(1));
      expect(api.posts.single.path, '/threads/$threadId/keys/family-sync');
      expect(api.posts.single.body['userId'], childUserId);
      final encryptedKey = api.posts.single.body['encryptedKey'] as String;
      expect(encryptedKey, isNotEmpty);

      final opened = await crypto.openSealedBox(
        sealedBox: encryptedKey,
        recipientKeyPair: prepared.child!,
      );
      expect(opened, prepared.threadKey);

      final getsAfterFirst = List<String>.from(api.gets);
      final postsAfterFirst = api.posts.length;

      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );

      expect(api.gets, getsAfterFirst);
      expect(api.posts.length, postsAfterFirst);
    });

    test('child without publicKey: silent return, zero POSTs', () async {
      const threadId = 'thread-family-2';
      const childUserId = 'child-no-key';
      await _prepareParentWithChildKeyAndMine(
        threadId: threadId,
        childUserId: childUserId,
        childHasPublicKey: false,
      );

      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );

      expect(api.posts, isEmpty);
      expect(
        api.gets,
        contains('/user/$childUserId/public-key'),
      );
      expect(
        api.gets.where((p) => p.contains('/keys/mine')),
        isEmpty,
      );
    });

    test('backend 409 already_exists: treated as success, child cached',
        () async {
      const threadId = 'thread-family-3';
      const childUserId = 'child-exists';
      await _prepareParentWithChildKeyAndMine(
        threadId: threadId,
        childUserId: childUserId,
        postError: const ApiException(409, 'already_exists'),
      );

      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );

      expect(api.posts, hasLength(1));

      final getsAfter = List<String>.from(api.gets);
      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );
      expect(api.gets, getsAfter);
      expect(api.posts, hasLength(1));
    });

    test('second call for same child/thread: zero extra network', () async {
      const threadId = 'thread-family-4';
      const childUserId = 'child-cached';
      await _prepareParentWithChildKeyAndMine(
        threadId: threadId,
        childUserId: childUserId,
      );

      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );

      final getsAfterFirst = api.gets.length;
      final postsAfterFirst = api.posts.length;

      await e2e.syncFamilyThreadKeyIfNeeded(
        threadId: threadId,
        childUserId: childUserId,
      );

      expect(api.gets.length, getsAfterFirst);
      expect(api.posts.length, postsAfterFirst);
    });
  });

  group('openCategoryChannel family cache hit', () {
    test('still invokes syncFamilyThreadKeyIfNeeded for Rodzina', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final counting = _CountingSyncE2e();
      final messaging = MessagingProvider(
        repository: MessagingRepository(
          apiClient: AppApiClient(baseUrl: 'http://fake'),
          offlineStore: OfflineStore(preferences: prefs),
        ),
        e2eSessionService: counting,
      );

      await messaging.createThread(
        subject: familyCategoryChannel,
        category: familyCategoryChannel,
        localOnly: true,
      );
      expect(messaging.getCategoryChannel(familyCategoryChannel), isNotNull);

      final thread = await messaging.openCategoryChannel(
        familyCategoryChannel,
        parentUserIds: const ['parent-a'],
        childUserIds: const ['child-x', 'child-y'],
      );

      expect(thread, isNotNull);
      expect(counting.syncCalls, hasLength(2));
      expect(
        counting.syncCalls.map((c) => c.childUserId).toList(),
        ['child-x', 'child-y'],
      );
      expect(
        counting.syncCalls.every((c) => c.threadId == thread!.id),
        isTrue,
      );
    });
  });
}
