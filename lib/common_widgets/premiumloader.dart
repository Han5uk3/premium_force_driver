import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A premium waveform / equalizer-style loader with silver metallic effects.
/// Renders [barCount] vertical bars that oscillate with staggered phases.
class PremiumLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final int barCount;
  final Duration duration;

  const PremiumLoader({
    super.key,
    this.size = 16,
    this.color,
    this.barCount = 7,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.size * 0.12;
    final gap = barWidth * 0.75;
    final totalWidth =
        (barWidth * widget.barCount) + (gap * (widget.barCount - 1));

    return SizedBox(
      width: totalWidth,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaveformPainter(
              progress: _controller.value,
              color: widget.color ?? const Color(0xFFC0C0C0),
              barCount: widget.barCount,
              barWidth: barWidth,
              gap: gap,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int barCount;
  final double barWidth;
  final double gap;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.barCount,
    required this.barWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxBarHeight = size.height;
    final minBarHeight = maxBarHeight * 0.15;
    final radius = Radius.circular(barWidth / 2);

    for (int i = 0; i < barCount; i++) {
      final phase = (i / barCount) * 2 * math.pi;
      final wave = math.sin(progress * 2 * math.pi - phase);
      final barHeight =
          minBarHeight + ((wave + 1) / 2) * (maxBarHeight - minBarHeight);
      final opacity = 0.4 + 0.6 * ((wave + 1) / 2);

      final left = i * (barWidth + gap);
      final top = (size.height - barHeight) / 2;

      final Rect rect = Rect.fromLTWH(left, top, barWidth, barHeight);

      // Metallic silver gradient for each bar
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha((opacity * 150).round()),
            color.withAlpha((opacity * 255).round()),
            color.withAlpha((opacity * 180).round()),
          ],
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A centred full-screen overlay with a semi-transparent background and the [PremiumLoader].
class PremiumLoaderOverlay extends StatelessWidget {
  final double loaderSize;

  const PremiumLoaderOverlay({super.key, this.loaderSize = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(140),
      child: Center(child: PremiumLoader(size: loaderSize)),
    );
  }
}
