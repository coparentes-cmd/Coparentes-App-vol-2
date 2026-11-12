import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

double _cardInner(double viewportWidth) {
  final narrow = viewportWidth < 900;
  final sidePad = narrow ? 16.0 : 24.0;
  final cardPad = narrow ? 16.0 : 36.0;
  if (narrow) {
    return viewportWidth - sidePad * 2 - cardPad * 2;
  }
  final contentWidth = viewportWidth.clamp(0.0, 1280.0);
  final formCol = contentWidth * (690 / (560 + 36 + 690));
  return formCol - cardPad * 2;
}

double _measure(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

Future<void> _loadPoppins() async {
  final medium = File('test/fonts/Poppins-Medium.ttf');
  final bold = File('test/fonts/Poppins-Bold.ttf');
  expect(medium.existsSync(), isTrue, reason: 'missing Poppins-Medium.ttf');
  expect(bold.existsSync(), isTrue, reason: 'missing Poppins-Bold.ttf');
  final loader = FontLoader('Poppins')
    ..addFont(Future.value(ByteData.sublistView(medium.readAsBytesSync())))
    ..addFont(Future.value(ByteData.sublistView(bold.readAsBytesSync())));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadPoppins);

  for (final viewport in [390.0, 1440.0]) {
    test('login labels fit at ${viewport.toInt()}px', () {
      const tabStyle = TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );
      const roleStyle = TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );
      const primaryStyle = TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w700,
      );
      const demoStyle = TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      );
      const forgotStyle = TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );
      const cookieStyle = TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w700,
      );

      final inner = _cardInner(viewport);
      final tabW = inner / 3;
      final roleTextW = (inner - 12) / 2 - 28;
      final cookieModal = (viewport - 32).clamp(0.0, 420.0);
      final cookieBtn = (cookieModal - 24 - 16) / 3;

      final checks = <(String, String, TextStyle, double)>[
        ('tab PL Logowanie', 'Logowanie', tabStyle, tabW),
        ('tab PL Rejestracja', 'Rejestracja', tabStyle, tabW),
        ('tab PL Dołączanie', 'Dołączanie', tabStyle, tabW),
        ('tab EN Sign in', 'Sign in', tabStyle, tabW),
        ('tab EN Register', 'Register', tabStyle, tabW),
        ('tab EN Join', 'Join', tabStyle, tabW),
        ('role PL Dorosły', 'Dorosły', roleStyle, roleTextW),
        ('role PL Dziecko', 'Dziecko', roleStyle, roleTextW),
        ('primary PL Zaloguj', 'Zaloguj', primaryStyle, inner),
        ('primary PL Zarejestruj', 'Zarejestruj', primaryStyle, inner),
        ('primary PL Dołącz', 'Dołącz', primaryStyle, inner),
        ('primary EN Create account', 'Create account', primaryStyle, inner),
        ('demo PL Tryb demo', 'Tryb demo', demoStyle, inner - 60),
        ('forgot PL', 'Nie pamiętam hasła', forgotStyle, inner),
        ('cookie PL Akceptuj', 'Akceptuj', cookieStyle, cookieBtn),
        ('cookie PL Odrzuć', 'Odrzuć', cookieStyle, cookieBtn),
        ('cookie PL Ustawienia', 'Ustawienia', cookieStyle, cookieBtn),
        ('cookie PL Zapisz wybór', 'Zapisz wybór', cookieStyle, cookieBtn),
      ];

      final failures = <String>[];
      for (final c in checks) {
        final needed = _measure(c.$2, c.$3);
        if (needed > c.$4 + 0.5) {
          failures.add(
            '${c.$1}: needs ${needed.toStringAsFixed(1)}px, '
            'has ${c.$4.toStringAsFixed(1)}px',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
