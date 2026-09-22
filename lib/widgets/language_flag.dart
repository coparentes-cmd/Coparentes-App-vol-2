import 'package:flutter/material.dart';

/// Circular official-style flags for the PL / EN language control.
class LanguageFlag extends StatelessWidget {
  final String languageCode;
  final double size;

  const LanguageFlag({
    super.key,
    required this.languageCode,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: languageCode == 'en' ? 'English' : 'Polski',
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: languageCode == 'en'
                ? const _UkFlagPainter()
                : const _PolandFlagPainter(),
          ),
        ),
      ),
    );
  }
}

class _PolandFlagPainter extends CustomPainter {
  const _PolandFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    final red = Paint()..color = const Color(0xFFDC143C);
    canvas.drawRect(Offset.zero & Size(size.width, size.height / 2), white);
    canvas.drawRect(
      Offset(0, size.height / 2) & Size(size.width, size.height / 2),
      red,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simplified Union Jack for the EN (en_GB) locale control.
class _UkFlagPainter extends CustomPainter {
  const _UkFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF012169));

    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = h * 0.22
      ..style = PaintingStyle.stroke;
    final red = Paint()
      ..color = const Color(0xFFC8102E)
      ..strokeWidth = h * 0.12
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(w, h), white);
    canvas.drawLine(Offset(w, 0), Offset(0, h), white);
    canvas.drawLine(Offset.zero, Offset(w, h), red);
    canvas.drawLine(Offset(w, 0), Offset(0, h), red);

    final whiteCross = Paint()..color = Colors.white;
    final redCross = Paint()..color = const Color(0xFFC8102E);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * 0.28,
        height: h,
      ),
      whiteCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w,
        height: h * 0.28,
      ),
      whiteCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * 0.16,
        height: h,
      ),
      redCross,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w,
        height: h * 0.16,
      ),
      redCross,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
