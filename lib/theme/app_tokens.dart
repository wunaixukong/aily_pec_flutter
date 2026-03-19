import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF5B6CF0);
  static const Color primaryContainer = Color(0xFFE4E8FF);
  static const Color secondary = Color(0xFF7A86B6);
  static const Color accent = Color(0xFF8B5CF6);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFDCE3F1);
  static const Color borderStrong = Color(0xFFC5D0E6);

  static const Color textPrimary = Color(0xFF182033);
  static const Color textSecondary = Color(0xFF62708A);
  static const Color textMuted = Color(0xFF8A96AD);

  static const Color success = Color(0xFF169B62);
  static const Color successSoft = Color(0xFFE9F8F1);
  static const Color warning = Color(0xFFCA8A04);
  static const Color warningSoft = Color(0xFFFFF7DB);
  static const Color error = Color(0xFFD14343);
  static const Color errorSoft = Color(0xFFFFECEC);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFEAF2FF);

  static const Color pomodoroWork = Color(0xFFE45B6B);
  static const Color pomodoroShortBreak = Color(0xFF2FA77A);
  static const Color pomodoroLongBreak = Color(0xFF4C6FFF);
}

class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

class AppGradients {
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.accent],
  );
}

class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF182033).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF182033).withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
