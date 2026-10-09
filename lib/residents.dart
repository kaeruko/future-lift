import 'dart:math' as math;

import 'package:flutter/material.dart';

// Artwork is isolated here so production assets can replace these original shapes.
enum Resident {
  child('こどものハル', Color(0xFFFFBB56)),
  student('学生のアオ', Color(0xFF7A8DE0)),
  adult('働くミドリ', Color(0xFF48AA99)),
  elder('まちのフミ', Color(0xFFDE869D));

  const Resident(this.label, this.color);
  final String label;
  final Color color;

  List<String> get tips => switch (this) {
    Resident.child => [
      '少し体を動かすことも、毎日のセルフケアになるんだって。',
      '家事や庭の手入れにも、体を動かす機会があるんだね。',
      '好きな遊びや趣味を、長く楽しめるといいね。',
      '身近な人とのつながりも、大切にしたいね。',
    ],
    Resident.student => [
      '新しいことを知る楽しさも、ずっと大切にしたいね。',
      '外に出るきっかけは、好きな場所を見つけることでもよさそう。',
      '体を動かす方法は、ひとつじゃないんだって。自分に合うものを。',
      '誰かと一緒だと、楽しめる活動もあるかもしれないね。',
    ],
    Resident.adult => [
      '暮らしの中で体を動かすことも、大切な活動なんだって。',
      '無理のない範囲で、楽しめる動き方を探してみたいね。',
      '人と話す時間も、日々のつながりを育てるひとときだね。',
      '自分が大切にしたいことを続けられる環境も、大事なんだって。',
    ],
    Resident.elder => [
      '年齢が同じでも、できることや必要な支えは人それぞれだね。',
      '支えを借りながらでも、自分の好きなことを楽しめるといいね。',
      '学んだり、人とつながったりすることも、生活する力のひとつだね。',
      '体調や暮らしに合う、自分なりのセルフケアを大切にしたいね。',
    ],
  };
}

class ResidentAvatar extends StatelessWidget {
  const ResidentAvatar({
    super.key,
    required this.resident,
    this.size = 80,
    this.clap = 0,
    this.celebrating = false,
  });
  final Resident resident;
  final double size;
  final double clap;
  final bool celebrating;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 1.25,
    child: CustomPaint(painter: _ResidentPainter(resident, clap, celebrating)),
  );
}

class _ResidentPainter extends CustomPainter {
  _ResidentPainter(this.resident, this.clap, this.celebrating);
  final Resident resident;
  final double clap;
  final bool celebrating;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 125);
    final paint = Paint()..isAntiAlias = true;
    void oval(Rect rect, Color color) =>
        canvas.drawOval(rect, paint..color = color);
    void line(Offset a, Offset b, Color color, double width) => canvas.drawLine(
      a,
      b,
      paint
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    const ink = Color(0xFF35465A);
    const skin = Color(0xFFFFD3AE);
    oval(const Rect.fromLTWH(17, 113, 66, 9), const Color(0x220D3841));
    line(const Offset(39, 97), const Offset(35, 112), ink, 11);
    line(const Offset(60, 97), const Offset(65, 112), ink, 11);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 60, 52, 42),
        const Radius.circular(17),
      ),
      paint..color = resident.color,
    );
    oval(const Rect.fromLTWH(24, 12, 52, 54), skin);
    final hair = resident == Resident.elder ? const Color(0xFFE2E7E9) : ink;
    canvas.drawArc(
      const Rect.fromLTWH(23, 8, 54, 43),
      math.pi,
      math.pi,
      true,
      paint..color = hair,
    );
    if (resident == Resident.student) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(20, 10, 60, 12),
          const Radius.circular(5),
        ),
        paint..color = resident.color,
      );
    }
    for (final x in [40.0, 60.0]) {
      if (celebrating) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(x, 40), width: 9, height: 7),
          math.pi,
          math.pi,
          false,
          paint
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        paint.style = PaintingStyle.fill;
      } else {
        oval(Rect.fromCircle(center: Offset(x, 39), radius: 2.2), ink);
      }
    }
    canvas.drawArc(
      const Rect.fromLTWH(43, 43, 14, 11),
      0,
      math.pi,
      false,
      paint
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    paint.style = PaintingStyle.fill;
    oval(const Rect.fromLTWH(29, 45, 9, 5), const Color(0xFFEEAA99));
    oval(const Rect.fromLTWH(62, 45, 9, 5), const Color(0xFFEEAA99));
    if (resident == Resident.elder) {
      for (final x in [39.0, 61.0]) {
        canvas.drawCircle(
          Offset(x, 39),
          9,
          paint
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      paint.style = PaintingStyle.fill;
      line(const Offset(48, 38), const Offset(52, 38), ink, 1.5);
    }
    final spread = celebrating ? 4 + 15 * clap : 27.0;
    final y = celebrating ? 68.0 : 88.0;
    line(const Offset(28, 72), Offset(50 - spread, y), skin, 10);
    line(const Offset(72, 72), Offset(50 + spread, y), skin, 10);
    if (celebrating && clap < .25) {
      for (final x in [37.0, 50.0, 63.0]) {
        line(
          Offset(x, 55),
          Offset(x + (x - 50) * .2, 48),
          const Color(0xFFFFD96B),
          3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ResidentPainter oldDelegate) =>
      oldDelegate.clap != clap ||
      oldDelegate.resident != resident ||
      oldDelegate.celebrating != celebrating;
}
