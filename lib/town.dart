import 'package:flutter/material.dart';

import 'residents.dart';

const townNames = ['穏やかなまち', '花のあるまち', '笑顔が集まるまち', 'にぎやかなまち'];
const townDescriptions = [
  'いつものまちで、みんなが暮らしています。',
  '道ばたに、色とりどりの花が咲きました。',
  '公園に、笑顔の住民が集まってきました。',
  '小さな飾りが、まちの日常を彩っています。',
];

class TownScene extends StatelessWidget {
  const TownScene({super.key, required this.level, this.onResident});
  final int level;
  final ValueChanged<Resident>? onResident;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.22,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final people = [
            (Resident.child, .12, .52),
            (Resident.student, .65, .49),
            (Resident.adult, .34, .67),
            (Resident.elder, .73, .73),
            if (level >= 2) (Resident.child, .05, .77),
            if (level >= 2) (Resident.adult, .49, .48),
          ];
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _TownPainter(level))),
              for (var index = 0; index < people.length; index++)
                Positioned(
                  left: width * people[index].$2,
                  top: height * people[index].$3,
                  child: Semantics(
                    button: onResident != null,
                    label: '${people[index].$1.label}のTips',
                    child: Tooltip(
                      message: people[index].$1.label,
                      child: InkWell(
                        key: ValueKey('resident-$index'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: onResident == null
                            ? null
                            : () => onResident!(people[index].$1),
                        child: ResidentAvatar(
                          resident: people[index].$1,
                          size: (width * .14).clamp(40.0, 76.0),
                          celebrating: level >= 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _TownPainter extends CustomPainter {
  _TownPainter(this.level);
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 400, size.height / 328);
    final paint = Paint()..isAntiAlias = true;
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double r = 0,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        paint..color = color,
      );
    }

    void circle(double x, double y, double r, Color color) =>
        canvas.drawCircle(Offset(x, y), r, paint..color = color);
    const grass = Color(0xFFC8E6C0);
    const leaf = Color(0xFF69AD85);
    rect(0, 0, 400, 328, const Color(0xFFDDF3F5));
    circle(335, 43, 25, const Color(0xFFFFDF87));
    rect(29, 39, 78, 15, Colors.white, 12);
    rect(61, 27, 31, 26, Colors.white, 15);
    rect(194, 22, 58, 13, Colors.white, 10);
    canvas.drawOval(
      const Rect.fromLTWH(-60, 110, 310, 130),
      paint..color = grass,
    );
    canvas.drawOval(
      const Rect.fromLTWH(170, 99, 300, 150),
      paint..color = grass,
    );
    rect(0, 170, 400, 160, grass);
    final path = Path()
      ..moveTo(183, 165)
      ..cubicTo(150, 215, 200, 234, 400, 265)
      ..lineTo(400, 302)
      ..cubicTo(137, 257, 104, 222, 150, 165)
      ..close();
    canvas.drawPath(path, paint..color = const Color(0xFFF9E5BA));
    void house(double x, double y, double w, double h, Color roof, Color wall) {
      rect(x + 4, y + h - 3, w, 8, const Color(0x180D3841), 4);
      rect(x, y, w, h, wall, 6);
      final roofPath = Path()
        ..moveTo(x - 8, y + 3)
        ..lineTo(x + w / 2, y - 28)
        ..lineTo(x + w + 8, y + 3)
        ..close();
      canvas.drawPath(roofPath, paint..color = roof);
      rect(x + w * .4, y + h - 28, 18, 28, const Color(0xFF73978E), 4);
      for (final dx in [12.0, w - 27]) {
        rect(x + dx, y + 13, 15, 18, const Color(0xFFBCE5EF), 3);
        rect(x + dx + 7, y + 13, 2, 18, Colors.white);
      }
    }

    house(43, 113, 83, 63, const Color(0xFFDC9179), const Color(0xFFFFF5DC));
    house(226, 108, 100, 77, const Color(0xFF729CBB), const Color(0xFFFFFAE9));
    rect(248, 116, 55, 15, const Color(0xFFF3C97A), 4);
    void tree(double x, double y) {
      rect(x - 4, y, 8, 40, const Color(0xFFAA9671), 3);
      circle(x, y - 2, 24, leaf);
      circle(x - 10, y + 7, 17, leaf);
      circle(x + 10, y + 7, 17, leaf);
    }

    tree(22, 146);
    tree(360, 137);
    tree(167, 102);
    rect(235, 245, 45, 8, const Color(0xFFC69B72), 3);
    rect(238, 232, 40, 10, const Color(0xFFC69B72), 3);
    rect(240, 253, 4, 10, const Color(0xFF907859));
    rect(272, 253, 4, 10, const Color(0xFF907859));
    if (level >= 1) {
      for (final spot in [
        (23.0, 241.0),
        (117.0, 282.0),
        (328.0, 211.0),
        (184.0, 175.0),
      ]) {
        for (var i = 0; i < 4; i++) {
          final x = spot.$1 + i * 9;
          rect(x, spot.$2, 2, 10, leaf);
          circle(
            x + 1,
            spot.$2,
            4,
            i.isEven ? const Color(0xFFEC93AC) : const Color(0xFFFFC867),
          );
          circle(x + 1, spot.$2, 1.5, const Color(0xFFFFFADE));
        }
      }
    }
    if (level >= 3) {
      canvas.drawLine(
        const Offset(35, 63),
        const Offset(366, 76),
        paint
          ..color = const Color(0xFF77968D)
          ..strokeWidth = 1.5,
      );
      for (var i = 0; i < 12; i++) {
        final x = 42.0 + i * 27;
        final y = 63 + i * 1.1;
        final flag = Path()
          ..moveTo(x, y)
          ..lineTo(x + 17, y + 1)
          ..lineTo(x + 8, y + 19)
          ..close();
        canvas.drawPath(
          flag,
          paint
            ..color = [
              const Color(0xFFDF8F9E),
              const Color(0xFFE9BD5D),
              const Color(0xFF79B4C1),
            ][i % 3],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TownPainter oldDelegate) => oldDelegate.level != level;
}
