import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against regressions: Text('…') / labelText / Tab text with Polish
/// diacritics must go through context.tr (except known data-key allowlist).
void main() {
  test('no unwrapped Polish Text/labelText/Tab literals in UI files', () {
    final root = Directory.current;
    final lib = Directory('${root.path}/lib');
    final skipDirs = {
      'l10n',
      'providers',
      'data',
      'models',
      'config',
      'services',
      'theme',
      'utils',
      'core',
      'api',
    };
    final pl = RegExp(r'[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]');
    final textLit = RegExp(
      r"""(?:const\s+)?Text\s*\(\s*(['"])((?:\\.|(?!\1).)*?)\1""",
    );
    final namedLit = RegExp(
      r"""(?:labelText|title|subtitle|hintText|tooltip|hint|emptyLabel)\s*:\s*(['"])((?:\\.|(?!\1).)*?)\1""",
    );
    final tabLit = RegExp(r"""Tab\(\s*text:\s*(['"])((?:\\.|(?!\1).)*?)\1""");

    final offenders = <String>[];
    for (final file in lib.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final rel = file.path.substring(lib.path.length + 1);
      final top = rel.split('/').first;
      if (skipDirs.contains(top)) continue;

      final source = file.readAsStringSync();
      for (final pat in [textLit, namedLit, tabLit]) {
        for (final m in pat.allMatches(source)) {
          final body = m.group(2)!;
          if (body.contains(r'$')) continue;
          if (!pl.hasMatch(body)) continue;
          final start = m.start;
          final win = source.substring(start > 50 ? start - 50 : 0, start);
          if (win.contains('context.tr(') || RegExp(r'tr\s*\(\s*$').hasMatch(win)) {
            continue;
          }
          final line = '\n'.allMatches(source.substring(0, start)).length + 1;
          offenders.add('lib/$rel:$line  ${body.length > 80 ? '${body.substring(0, 80)}…' : body}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Unwrapped Polish UI literals:\n${offenders.join('\n')}',
    );
  });
}
