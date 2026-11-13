import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GlowBackground extends StatelessWidget {
  const GlowBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -130,
          left: -120,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.24),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -120,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
