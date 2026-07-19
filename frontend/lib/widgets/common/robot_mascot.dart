// lib/widgets/common/robot_mascot.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

// ✅ ADDED: waving expression
enum RobotExpression { happy, sad, celebrating, thinking, waving }

class RobotMascot extends StatefulWidget {
  final RobotExpression expression;
  final double size;

  const RobotMascot({
    super.key,
    this.expression = RobotExpression.happy,
    this.size = 96,
  });

  @override
  State<RobotMascot> createState() => _RobotMascotState();
}

class _RobotMascotState extends State<RobotMascot>
    with SingleTickerProviderStateMixin {
  late AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size * 1.2,
          child: CustomPaint(
            painter: _RobotPainter(
              expression: widget.expression,
              t: _loop.value,
            ),
          ),
        );
      },
    );
  }
}

class _RobotPainter extends CustomPainter {
  final RobotExpression expression;
  final double t;

  _RobotPainter({required this.expression, required this.t});

  static const _navyDark = Color(0xFF10182E);
  static const _navyLight = Color(0xFF2D3A5C);
  static const _cream = Color(0xFFFDFDFB);
  static const _creamShade = Color(0xFFEFEFEC);
  static const _blush = Color(0xFFFBA98C);
  static const _ink = Color(0xFF1B2440);
  static const _tealHighlight = Color(0xFF5FF0CC);
  static const _tealMid = Color(0xFF2EC9A8);
  static const _blueDeep = Color(0xFF1360E2);
  static const _earTealLight = Color(0xFF7FF5D8);
  static const _earTealDark = Color(0xFF1FA888);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final floatY = math.sin(t * 2 * math.pi) * w * 0.02;
    final bounce = expression == RobotExpression.celebrating
        ? math.sin(t * 2 * math.pi * 2).abs() * w * 0.045
        : 0.0;

    final center = Offset(w / 2, w / 2 + w * 0.05);

    _drawShadow(canvas, size, w);

    canvas.save();
    canvas.translate(0, -floatY - bounce);

    _drawAntenna(canvas, center, w);
    _drawEar(canvas, center, w);
    _drawBodyRim(canvas, center, w);
    _drawFaceBase(canvas, center, w);
    _drawSidePanel(canvas, center, w);
    _drawGlossSweep(canvas, center, w);
    _drawFace(canvas, center, w);
    _drawTopHighlightBand(canvas, center, w);

    // ✅ Waving arm drawn on top of body so it appears in front
    if (expression == RobotExpression.waving) {
      _drawWavingArm(canvas, center, w);
    }

    canvas.restore();
  }

  Shader _rimShader(Rect bounds) => RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 0.85,
        colors: const [_tealHighlight, _tealMid, _blueDeep],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bounds);

  Shader _earShader(Rect bounds) => RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 0.8,
        colors: const [_earTealLight, _earTealDark],
      ).createShader(bounds);

  Shader _navyShader(Rect bounds) => RadialGradient(
        center: const Alignment(0.2, -0.6),
        radius: 0.9,
        colors: const [_navyLight, _navyDark],
      ).createShader(bounds);

  Shader _faceShader(Rect bounds) => const LinearGradient(
        begin: Alignment(-0.7, -1),
        end: Alignment(1, 1),
        colors: [_cream, _creamShade],
      ).createShader(bounds);

  void _drawShadow(Canvas canvas, Size size, double w) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.92),
        width: w * 0.5,
        height: w * 0.08,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawAntenna(Canvas canvas, Offset center, double w) {
    final baseX = center.dx - w * 0.08;
    final baseY = center.dy - w * 0.34;
    double tipX = baseX - w * 0.07;
    double tipY = baseY - w * 0.1;

    if (expression == RobotExpression.thinking) {
      tipX += math.sin(t * 2 * math.pi * 3) * w * 0.03;
    } else if (expression == RobotExpression.sad) {
      tipX -= w * 0.015;
      tipY += w * 0.025;
    } else if (expression == RobotExpression.celebrating) {
      tipY -= math.sin(t * 2 * math.pi * 3).abs() * w * 0.02;
    } else if (expression == RobotExpression.waving) {
      // Antenna bobs slightly with the wave rhythm
      tipY += math.sin(t * 2 * math.pi * 2.5) * w * 0.01;
    }

    canvas.drawCircle(
      Offset(tipX + w * 0.005, tipY + w * 0.01),
      w * 0.05,
      Paint()..color = Colors.black.withValues(alpha: 0.06),
    );
    canvas.drawLine(
      Offset(baseX, baseY),
      Offset(tipX, tipY),
      Paint()
        ..color = _blueDeep
        ..strokeWidth = w * 0.02
        ..strokeCap = StrokeCap.round,
    );
    final ballRect =
        Rect.fromCircle(center: Offset(tipX, tipY), radius: w * 0.042);
    canvas.drawCircle(
        Offset(tipX, tipY), w * 0.042, Paint()..shader = _rimShader(ballRect));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tipX - w * 0.012, tipY - w * 0.012),
        width: w * 0.018,
        height: w * 0.014,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  void _drawEar(Canvas canvas, Offset center, double w) {
    final earCenter = Offset(center.dx + w * 0.33, center.dy - w * 0.31);
    final radius = w * 0.125;
    canvas.drawCircle(
      Offset(earCenter.dx + w * 0.008, earCenter.dy + w * 0.015),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.05),
    );
    final rect = Rect.fromCircle(center: earCenter, radius: radius);
    canvas.drawCircle(earCenter, radius, Paint()..shader = _earShader(rect));
    canvas.drawOval(
      Rect.fromCenter(
        center:
            Offset(earCenter.dx - radius * 0.35, earCenter.dy - radius * 0.4),
        width: radius * 0.6,
        height: radius * 0.42,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  Rect _bodyRect(Offset center, double w) => Rect.fromCenter(
        center: center,
        width: w * 0.72,
        height: w * 0.72,
      );

  void _drawBodyRim(Canvas canvas, Offset center, double w) {
    final rimRect = _bodyRect(center, w).inflate(w * 0.022);
    final rimRRect =
        RRect.fromRectAndRadius(rimRect, Radius.circular(w * 0.27));
    canvas.drawRRect(rimRRect, Paint()..shader = _rimShader(rimRect));
  }

  void _drawFaceBase(Canvas canvas, Offset center, double w) {
    final bodyRect = _bodyRect(center, w);
    final rrect = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.25));
    canvas.drawRRect(rrect, Paint()..shader = _faceShader(bodyRect));
  }

  void _drawSidePanel(Canvas canvas, Offset center, double w) {
    final bodyRect = _bodyRect(center, w);
    final outerRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.25));
    canvas.save();
    canvas.clipRRect(outerRRect);

    final panelPath = Path()
      ..moveTo(center.dx + w * 0.135, center.dy - w * 0.355)
      ..quadraticBezierTo(
        center.dx + w * 0.385,
        center.dy - w * 0.10,
        center.dx + w * 0.285,
        center.dy + w * 0.355,
      )
      ..lineTo(center.dx + w * 0.48, center.dy + w * 0.355)
      ..lineTo(center.dx + w * 0.48, center.dy - w * 0.355)
      ..close();

    final panelBounds = Rect.fromLTWH(
      center.dx,
      center.dy - w * 0.36,
      w * 0.36,
      w * 0.72,
    );
    canvas.drawPath(panelPath, Paint()..shader = _navyShader(panelBounds));

    final moonCenter = Offset(center.dx + w * 0.255, center.dy + w * 0.018);
    canvas.drawCircle(moonCenter, w * 0.072, Paint()..color = _cream);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(moonCenter.dx - w * 0.02, moonCenter.dy - w * 0.02),
        width: w * 0.025,
        height: w * 0.018,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      Offset(center.dx + w * 0.19, center.dy - w * 0.135),
      w * 0.017,
      Paint()..color = _cream.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  void _drawGlossSweep(Canvas canvas, Offset center, double w) {
    final bodyRect = _bodyRect(center, w);
    final outerRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.25));
    canvas.save();
    canvas.clipRRect(outerRRect);
    final glossRect = Rect.fromCircle(
      center: Offset(center.dx - w * 0.12, center.dy - w * 0.16),
      radius: w * 0.42,
    );
    canvas.drawOval(
      glossRect,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ]).createShader(glossRect),
    );
    canvas.restore();
  }

  void _drawTopHighlightBand(Canvas canvas, Offset center, double w) {
    final bodyRect = _bodyRect(center, w);
    final bandRect = Rect.fromLTWH(
      bodyRect.left,
      bodyRect.top,
      bodyRect.width,
      bodyRect.height * 0.22,
    );
    final outerRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.25));
    canvas.save();
    canvas.clipRRect(outerRRect);
    canvas.drawRect(
        bandRect, Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.restore();
  }

  // ── Face dispatcher ──────────────────────────────────────────────────────
  void _drawFace(Canvas canvas, Offset center, double w) {
    final faceCenter = Offset(center.dx - w * 0.065, center.dy + w * 0.02);
    _drawCheeks(canvas, faceCenter, w);

    switch (expression) {
      case RobotExpression.happy:
        _drawDotEyes(canvas, faceCenter, w, blink: true);
        // ✅ FIXED: proper upward-curving arc smile instead of filled oval
        _drawSmile(canvas, faceCenter, w);
        break;
      case RobotExpression.sad:
        _drawSadEyes(canvas, faceCenter, w);
        _drawFrown(canvas, faceCenter, w);
        break;
      case RobotExpression.celebrating:
        _drawDotEyes(canvas, faceCenter, w, blink: false, wide: true);
        _drawBigSmile(canvas, faceCenter, w);
        break;
      case RobotExpression.thinking:
        _drawLookingEyes(canvas, faceCenter, w);
        _drawSmallO(canvas, faceCenter, w);
        break;
      case RobotExpression.waving:
        // Happy eyes + smile, same as happy but no blink (focused wave)
        _drawDotEyes(canvas, faceCenter, w, blink: false);
        _drawSmile(canvas, faceCenter, w);
        break;
    }
  }

  void _drawCheeks(Canvas canvas, Offset c, double w) {
    final paint = Paint()..color = _blush.withValues(alpha: 0.65);
    final eyeOffsetX = w * 0.11;
    final cheekY = c.dy + w * 0.065;
    canvas.drawCircle(Offset(c.dx - eyeOffsetX, cheekY), w * 0.033, paint);
    canvas.drawCircle(Offset(c.dx + eyeOffsetX, cheekY), w * 0.033, paint);
  }

  void _drawDotEyes(Canvas canvas, Offset c, double w,
      {bool blink = false, bool wide = false}) {
    final paint = Paint()..color = _ink;
    final eyeOffsetX = wide ? w * 0.13 : w * 0.11;
    final eyeY = c.dy - w * 0.01;
    final blinkSquash =
        (blink && t > 0.92) ? (1 - (t - 0.92) / 0.08).clamp(0.1, 1.0) : 1.0;
    final eyeH = w * 0.048 * blinkSquash;
    final eyeW = w * 0.036;

    for (final dx in [-eyeOffsetX, eyeOffsetX]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(c.dx + dx, eyeY), width: eyeW, height: eyeH),
          Radius.circular(eyeW / 2),
        ),
        paint,
      );
    }
  }

  void _drawSadEyes(Canvas canvas, Offset c, double w) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = w * 0.019
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final eyeOffsetX = w * 0.11;
    final eyeY = c.dy;
    for (final dx in [-eyeOffsetX, eyeOffsetX]) {
      final rect = Rect.fromCenter(
          center: Offset(c.dx + dx, eyeY), width: w * 0.065, height: w * 0.065);
      canvas.drawArc(rect, math.pi * 1.1, math.pi * 0.6, false, paint);
    }
  }

  void _drawLookingEyes(Canvas canvas, Offset c, double w) {
    final paint = Paint()..color = _ink;
    final eyeOffsetX = w * 0.11;
    final lookShift = math.sin(t * 2 * math.pi) * w * 0.011;
    final eyeY = c.dy - w * 0.014;
    for (final dx in [-eyeOffsetX, eyeOffsetX]) {
      canvas.drawCircle(Offset(c.dx + dx + lookShift, eyeY), w * 0.021, paint);
    }
  }

  // ── ✅ FIXED: proper upward-curving arc smile ────────────────────────────
  // How the arc math works:
  //   Flutter drawArc angles go clockwise from positive-x (right).
  //   canvas Y increases downward, so:
  //     90°  (pi/2)    = bottom of the arc rect
  //     270° (3*pi/2)  = top of the arc rect
  //   A smile bows DOWNWARD in canvas (center of arc is below the endpoints).
  //   That means the arc passes through 90° (bottom of rect).
  //   startAngle ≈ 0.12*pi (just past right), sweepAngle = 0.76*pi
  //   → arc goes from right → bottom → left → upward-curving smile ✓
  void _drawSmile(Canvas canvas, Offset c, double w) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = w * 0.026
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + w * 0.072),
      width: w * 0.155,
      height: w * 0.10,
    );
    canvas.drawArc(rect, math.pi * 0.12, math.pi * 0.76, false, paint);
  }

  // Wider, more exuberant version of the smile for celebrating
  void _drawBigSmile(Canvas canvas, Offset c, double w) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = w * 0.030
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(
      center: Offset(c.dx, c.dy + w * 0.08),
      width: w * 0.20,
      height: w * 0.13,
    );
    canvas.drawArc(rect, math.pi * 0.10, math.pi * 0.80, false, paint);
  }

  void _drawFrown(Canvas canvas, Offset c, double w) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromCenter(
        center: Offset(c.dx, c.dy + w * 0.18),
        width: w * 0.11,
        height: w * 0.085);
    canvas.drawArc(rect, math.pi * 1.15, math.pi * 0.7, false, paint);
  }

  void _drawSmallO(Canvas canvas, Offset c, double w) {
    canvas.drawCircle(
      Offset(c.dx, c.dy + w * 0.125),
      w * 0.02,
      Paint()..color = _ink,
    );
  }

  // ── ✅ NEW: Waving arm ─────────────────────────────────────────────────
  // Arm attaches to the RIGHT side of the body (just below the ear).
  // A single rounded stroke acts as the arm.
  // The hand is a small glossy circle at the tip.
  // Animation: arm sweeps between ~45° above horizontal and horizontal,
  // giving a friendly "hello!" wave at 2.5× the base float frequency.
  void _drawWavingArm(Canvas canvas, Offset center, double w) {
    // Shoulder: right side of body, roughly mid-upper area
    final shoulderX = center.dx + w * 0.345;
    final shoulderY = center.dy - w * 0.02;

    // Wave: oscillates between pointing up-right (~-70°) and right (~0°)
    // math.pi * -0.55 = ~-99° (upper-right), * 0.30 amplitude
    final waveAngle =
        -math.pi * 0.55 + math.sin(t * 2 * math.pi * 2.5) * math.pi * 0.30;

    final armLen = w * 0.22;
    final handX = shoulderX + math.cos(waveAngle) * armLen;
    final handY = shoulderY + math.sin(waveAngle) * armLen;

    // Arm stroke — same teal-to-blue palette as the body rim
    final armRect = Rect.fromPoints(
      Offset(shoulderX - w * 0.05, shoulderY - w * 0.05),
      Offset(handX + w * 0.05, handY + w * 0.05),
    );
    canvas.drawLine(
      Offset(shoulderX, shoulderY),
      Offset(handX, handY),
      Paint()
        ..shader = _rimShader(armRect)
        ..strokeWidth = w * 0.085
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Hand circle
    final handCircleRect = Rect.fromCircle(
      center: Offset(handX, handY),
      radius: w * 0.055,
    );
    canvas.drawCircle(
      Offset(handX, handY),
      w * 0.055,
      Paint()..shader = _rimShader(handCircleRect),
    );

    // Gloss on hand
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(handX - w * 0.016, handY - w * 0.016),
        width: w * 0.024,
        height: w * 0.017,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.t != t || old.expression != expression;
}

// ── Convenience wrapper (unchanged API) ─────────────────────────────────────

class RobotMascotBubble extends StatelessWidget {
  final RobotExpression expression;
  final double size;
  final Color? backgroundColor;
  final bool transparent;

  const RobotMascotBubble({
    super.key,
    this.expression = RobotExpression.happy,
    this.size = 72,
    this.backgroundColor,
    this.transparent = true,
  });

  @override
  Widget build(BuildContext context) {
    final mascot = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: RobotMascot(
        key: ValueKey(expression),
        expression: expression,
        size: size * 0.95,
      ),
    );

    if (transparent) {
      return SizedBox(width: size, height: size * 1.2, child: mascot);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(child: mascot),
    );
  }
}
