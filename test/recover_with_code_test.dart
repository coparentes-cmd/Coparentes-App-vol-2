import 'package:coparentes/data/api/app_api_client.dart';
import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:coparentes/services/e2e_session_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecoverApiClient extends AppApiClient {
  _RecoverApiClient({required this.mineResponse})
      : super(baseUrl: 'http://fake');

  Map<String, dynamic> mineResponse;
  final posts = <({String path, Map<String, dynamic> body})>[];

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    if (path == '/user/keys/mine') {
      return Map<String, dynamic>.from(mineResponse);
    }
    throw ApiException(404, 'not_found');
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    Map<String, String>? extraHeaders,
  }) async {
    posts.add((path: path, body: Map<String, dynamic>.from(body)));
    return {'success': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const argonTimeout = Timeout(Duration(minutes: 2));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('E2eCryptoService.normalizeRecoveryCodeInput', () {
    test('variants of the same code normalize to identical canonical form', () {
      const canonical = 'ABCD-EFGH-JKMN-PQRS-TVWX-YZ01';
      final variants = <String>[
        canonical,
        'abcd-efgh-jkmn-pqrs-tvwx-yz01',
        'ABCDEFGHJKMNPQRSTVWXYZ01',
        '  ABCD EFGH JKMN PQRS TVWX YZ01  ',
        'abcd efgh jkmn-pqrs tvwx yz01',
        'AbCd-EfGh-JkMn-PqRs-TvWx-Yz01',
      ];
      for (final raw in variants) {
        expect(
          E2eCryptoService.normalizeRecoveryCodeInput(raw),
          canonical,
          reason: 'input: $raw',
        );
      }
    });

    test('matches createRecoveryCode output byte-for-byte after mangling', () {
      final crypto = E2eCryptoService();
      final original = crypto.createRecoveryCode();
      final mangled =
          '  ${original.toLowerCase().replaceAll('-', ' ')}  ';
      expect(
        E2eCryptoService.normalizeRecoveryCodeInput(mangled),
        original,
      );
    });

    test('wrong length returns stripped form without regrouping', () {
      expect(
        E2eCryptoService.normalizeRecoveryCodeInput('ABCD-EFGH'),
        'ABCDEFGH',
      );
    });
  });

  group('E2eSessionService.recoverWithCode', () {
    test(
      'success: same private key, unchanged publicKey, posts /user/keys',
      () async {
        final crypto = E2eCryptoService();
        final keyPair = await crypto.generateKeyPair();
        final originalPrivate = await keyPair.extractPrivateKeyBytes();
        final originalPublic = await keyPair.extractPublicKey();
        final encodedPublic = crypto.encodePublicKey(originalPublic);

        final recoveryCode = crypto.createRecoveryCode();
        const currentPassword = 'CurrentLoginPass1!';
        final recoveryEnvelope = await crypto.createPrivateKeyEnvelope(
          keyPair: keyPair,
          password: recoveryCode,
        );
        // Orphaned password envelope (different wrapping secret) — irrelevant
        // for recoverWithCode, which only needs recoveryKeyEnvelope.
        final orphanPasswordEnvelope = await crypto.createPrivateKeyEnvelope(
          keyPair: keyPair,
          password: 'OldPasswordThatNoLongerWorks!',
        );

        final api = _RecoverApiClient(
          mineResponse: {
            'publicKey': encodedPublic,
            'privateKeyEnvelope': orphanPasswordEnvelope,
            'recoveryKeyEnvelope': recoveryEnvelope,
          },
        );
        final e2e = E2eSessionService(apiClient: api);

        await e2e.recoverWithCode(
          recoveryCode.toLowerCase().replaceAll('-', ''),
          currentPassword,
        );

        expect(api.posts.length, 1);
        expect(api.posts.single.path, '/user/keys');
        expect(api.posts.single.body['publicKey'], encodedPublic);
        expect(api.posts.single.body['currentPassword'], currentPassword);
        expect(
          (api.posts.single.body['privateKeyEnvelope'] as String).isNotEmpty,
          isTrue,
        );
        expect(
          api.posts.single.body['privateKeyEnvelope'],
          isNot(orphanPasswordEnvelope),
        );

        final unlocked = await e2e.keyStorage.useUnlockedKeyPair(
          (kp) async => (
            private: await kp.extractPrivateKeyBytes(),
            public: (await kp.extractPublicKey()).bytes,
          ),
        );
        expect(unlocked.private, originalPrivate);
        expect(unlocked.public, originalPublic.bytes);

        // New password envelope opens with currentPassword to the same seed.
        final rewrapped = await crypto.decryptPrivateKeyEnvelope(
          envelope: api.posts.single.body['privateKeyEnvelope'] as String,
          password: currentPassword,
        );
        expect(await rewrapped.extractPrivateKeyBytes(), originalPrivate);
      },
      timeout: argonTimeout,
    );

    test(
      'wrong code: InvalidPasswordException and no POST',
      () async {
        final crypto = E2eCryptoService();
        final keyPair = await crypto.generateKeyPair();
        final publicKey = await keyPair.extractPublicKey();
        final recoveryCode = crypto.createRecoveryCode();
        final recoveryEnvelope = await crypto.createPrivateKeyEnvelope(
          keyPair: keyPair,
          password: recoveryCode,
        );

        final api = _RecoverApiClient(
          mineResponse: {
            'publicKey': crypto.encodePublicKey(publicKey),
            'privateKeyEnvelope': 'unused',
            'recoveryKeyEnvelope': recoveryEnvelope,
          },
        );
        final e2e = E2eSessionService(apiClient: api);

        await expectLater(
          () => e2e.recoverWithCode(
            '0000-0000-0000-0000-0000-0000',
            'AnyPassword1!',
          ),
          throwsA(isA<InvalidPasswordException>()),
        );
        expect(api.posts, isEmpty);
      },
      timeout: argonTimeout,
    );

    test(
      'missing recoveryKeyEnvelope: RecoveryCodeNotSetUpException before decrypt',
      () async {
        final api = _RecoverApiClient(
          mineResponse: {
            'publicKey': 'abc',
            'privateKeyEnvelope': 'env',
            'recoveryKeyEnvelope': null,
          },
        );
        final e2e = E2eSessionService(apiClient: api);

        await expectLater(
          () => e2e.recoverWithCode('ABCD-EFGH-JKMN-PQRS-TVWX-YZ01', 'pass'),
          throwsA(isA<RecoveryCodeNotSetUpException>()),
        );
        expect(api.posts, isEmpty);
      },
    );

    test(
      'empty recoveryKeyEnvelope: RecoveryCodeNotSetUpException',
      () async {
        final api = _RecoverApiClient(
          mineResponse: {
            'publicKey': 'abc',
            'privateKeyEnvelope': 'env',
            'recoveryKeyEnvelope': '',
          },
        );
        final e2e = E2eSessionService(apiClient: api);

        await expectLater(
          () => e2e.recoverWithCode('ABCD-EFGH-JKMN-PQRS-TVWX-YZ01', 'pass'),
          throwsA(isA<RecoveryCodeNotSetUpException>()),
        );
        expect(api.posts, isEmpty);
      },
    );
  });
}
