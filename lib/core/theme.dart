import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF1E2025);
  static const shadowLight = Color(0xFF2A2D35);
  static const shadowDark = Color(0xFF121316);
  static const accent = Color(0xFFC2185B); // Reddish-pink
  static const textMain = Colors.white;
  static const textSecondary = Colors.white70;
}

class Neumorphic {
  static BoxDecoration box({double radius = 20, Color? color}) { // 'Color? color' yahan hona chahiye
    return BoxDecoration(
      color: color ?? AppColors.background,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadowDark,
          offset: Offset(5, 5),
          blurRadius: 10,
        ),
        BoxShadow(
          color: AppColors.shadowLight,
          offset: Offset(-5, -5),
          blurRadius: 10,
        ),
      ],
    );
  }
}