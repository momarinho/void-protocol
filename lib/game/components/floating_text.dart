import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingTextComponent extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  final double duration;
  double timer = 0.0;
  final Vector2 velocity;

  late final TextPainter _fgPainter;
  late final TextPainter _shadowPainter;
  int _lastAlphaStep = -1;

  FloatingTextComponent({
    required Vector2 position,
    required this.text,
    this.color = Colors.white,
    this.fontSize = 14.0,
    this.duration = 0.8,
    Vector2? velocity,
  }) : velocity = velocity ?? Vector2(0, -50) {
    this.position = position;
    _fgPainter = TextPainter(textDirection: TextDirection.ltr);
    _shadowPainter = TextPainter(textDirection: TextDirection.ltr);
    _updatePainters(255);
  }

  void _updatePainters(int alpha) {
    final step = alpha >> 4; // 16 discrete opacity buckets (~10 updates across 0.8s)
    if (step == _lastAlphaStep) return;
    _lastAlphaStep = step;
    final steppedAlpha = ((step * 16) + 15).clamp(0, 255);

    _shadowPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Rajdhani',
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.black.withAlpha(steppedAlpha),
      ),
    );
    _shadowPainter.layout();

    _fgPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Rajdhani',
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color.withAlpha(steppedAlpha),
      ),
    );
    _fgPainter.layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    velocity.y += 35.0 * dt; // Gentle gravity arc for combat feel
    timer += dt;
    if (timer >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = timer / duration;
    final alpha = (255 * (1.0 - progress)).clamp(0, 255).toInt();
    if (alpha <= 0) return;

    _updatePainters(alpha);

    // Juice scale pop on appearance (Nova Drift / Diablo style)
    final scale = (timer < 0.12)
        ? 1.0 + 0.32 * (1.0 - (timer / 0.12))
        : 1.0;

    final dx = -_fgPainter.width / 2;
    final dy = -_fgPainter.height / 2;

    if (scale != 1.0) {
      canvas.save();
      canvas.scale(scale);
      _shadowPainter.paint(canvas, Offset(dx + 1.2, dy + 1.2));
      _fgPainter.paint(canvas, Offset(dx, dy));
      canvas.restore();
    } else {
      _shadowPainter.paint(canvas, Offset(dx + 1.2, dy + 1.2));
      _fgPainter.paint(canvas, Offset(dx, dy));
    }
  }
}
