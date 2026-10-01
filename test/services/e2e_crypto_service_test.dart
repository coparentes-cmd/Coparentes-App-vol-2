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

  test('Crockford alphabet excludes I, L, O, U', () {
    expect(E2eCryptoService.crockfordAlphabet.length, 32);
    expect(E2eCryptoService.crockfordAlphabet.contains('I'), isFalse);
    expect(E2eCryptoService.crockfordAlphabet.contains('L'), isFalse);
    expect(E2eCryptoService.crockfordAlphabet.contains('O'), isFalse);
    expect(E2eCryptoService.crockfordAlphabet.contains('U'), isFalse);
  });

  test('encodeCrockfordBase32: 15 zero bytes → 24 zeros', () {
    final encoded = E2eCryptoService.encodeCrockfordBase32(List.filled(15, 0));
    expect(encoded.length, 24);
    expect(encoded, '0' * 24);
  });

  test('createRecoveryCode format: 6 groups of 4 Crockford symbols', () {
    final code = crypto.createRecoveryCode();
    expect(
      code,
      matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4}){5}$')),
    );
    final compact = code.replaceAll('-', '');
    expect(compact.length, 24);
    for (final ch in compact.split('')) {
      expect(E2eCryptoService.crockfordAlphabet.contains(ch), isTrue);
    }
  });

  test('createRecoveryCode yields distinct codes', () {
    expect(crypto.createRecoveryCode(), isNot(crypto.createRecoveryCode()));
  });

  test(
    'same keyPair wrapped under password and recovery code decrypts to same private key',
    () async {
      final keyPair = await crypto.generateKeyPair();
      final originalPrivate = await keyPair.extractPrivateKeyBytes();
      const password = 'AccountPassword1!';
      final recoveryCode = crypto.createRecoveryCode();

      final passwordEnvelope = await crypto.createPrivateKeyEnvelope(
        keyPair: keyPair,
        password: password,
      );
      final recoveryEnvelope = await crypto.createPrivateKeyEnvelope(
        keyPair: keyPair,
        password: recoveryCode,
      );

      expect(passwordEnvelope, isNot(recoveryEnvelope));

      final fromPassword = await crypto.decryptPrivateKeyEnvelope(
        envelope: passwordEnvelope,
        password: password,
      );
      final fromRecovery = await crypto.decryptPrivateKeyEnvelope(
        envelope: recoveryEnvelope,
        password: recoveryCode,
      );

      expect(await fromPassword.extractPrivateKeyBytes(), originalPrivate);
      expect(await fromRecovery.extractPrivateKeyBytes(), originalPrivate);
    },
    timeout: argonTimeout,
  );
}
