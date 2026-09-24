import 'dart:convert';

import 'package:coparentes/services/e2e_crypto_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final crypto = E2eCryptoService();

  // Argon2id (memory 19456 KiB) is intentionally heavy in pure Dart.
  const argonTimeout = Timeout(Duration(minutes: 2));

  test(
    'round-trip: generate → envelope → decrypt restores private key',
    () async {
      final keyPair = await crypto.generateKeyPair();
      final originalPrivate = await keyPair.extractPrivateKeyBytes();
      final originalPublic = await keyPair.extractPublicKey();

      final envelope = await crypto.createPrivateKeyEnvelope(
        keyPair: keyPair,
        password: 'correct-horse-battery-staple',
      );

      expect(envelope, contains('"v":1'));
      expect(envelope, contains('"argon2id"'));
      expect(envelope, contains('"aes256gcm"'));

      final restored = await crypto.decryptPrivateKeyEnvelope(
        envelope: envelope,
        password: 'correct-horse-battery-staple',
      );

      expect(await restored.extractPrivateKeyBytes(), originalPrivate);
      expect(restored.publicKey.bytes, originalPublic.bytes);
      expect(restored.type, KeyPairType.x25519);
    },
    timeout: argonTimeout,
  );

  test(
    'decryptPrivateKeyEnvelope with wrong password throws InvalidPasswordException',
    () async {
      final keyPair = await crypto.generateKeyPair();
      final envelope = await crypto.createPrivateKeyEnvelope(
        keyPair: keyPair,
        password: 'right-password',
      );

      await expectLater(
        () => crypto.decryptPrivateKeyEnvelope(
          envelope: envelope,
          password: 'wrong-password',
        ),
        throwsA(isA<InvalidPasswordException>()),
      );
    },
    timeout: argonTimeout,
  );

  test('encodePublicKey / decodePublicKey round-trip', () async {
    final keyPair = await crypto.generateKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    final encoded = crypto.encodePublicKey(publicKey);
    final decoded = crypto.decodePublicKey(encoded);

    expect(decoded.bytes, publicKey.bytes);
    expect(decoded.type, KeyPairType.x25519);
    expect(encoded, isNot(contains('!'))); // standard base64
  });

  test('sealed box round-trip restores plaintext', () async {
    final recipient = await (await crypto.generateKeyPair()).extract();
    final plaintext = List<int>.generate(32, (i) => i + 1);

    final sealed = await crypto.sealForRecipient(
      plaintext: plaintext,
      recipientPublicKey: recipient.publicKey,
    );

    expect(sealed, contains('"v":1'));
    expect(sealed, contains('ephemeralPublicKey'));

    final opened = await crypto.openSealedBox(
      sealedBox: sealed,
      recipientKeyPair: recipient,
    );
    expect(opened, plaintext);
  });

  test(
    'openSealedBox with wrong key pair throws SealedBoxDecryptionException',
    () async {
      final recipient = await (await crypto.generateKeyPair()).extract();
      final wrong = await (await crypto.generateKeyPair()).extract();
      final plaintext = utf8.encode('thread-key-material');

      final sealed = await crypto.sealForRecipient(
        plaintext: plaintext,
        recipientPublicKey: recipient.publicKey,
      );

      await expectLater(
        () => crypto.openSealedBox(
          sealedBox: sealed,
          recipientKeyPair: wrong,
        ),
        throwsA(isA<SealedBoxDecryptionException>()),
      );
    },
  );

  test(
    'sealForRecipient is non-deterministic for same plaintext and recipient',
    () async {
      final recipient = await (await crypto.generateKeyPair()).extract();
      const plaintext = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0];

      final first = await crypto.sealForRecipient(
        plaintext: plaintext,
        recipientPublicKey: recipient.publicKey,
      );
      final second = await crypto.sealForRecipient(
        plaintext: plaintext,
        recipientPublicKey: recipient.publicKey,
      );

      expect(first, isNot(equals(second)));

      // Both still open to the same plaintext.
      expect(
        await crypto.openSealedBox(
          sealedBox: first,
          recipientKeyPair: recipient,
        ),
        plaintext,
      );
      expect(
        await crypto.openSealedBox(
          sealedBox: second,
          recipientKeyPair: recipient,
        ),
        plaintext,
      );
    },
  );
}
