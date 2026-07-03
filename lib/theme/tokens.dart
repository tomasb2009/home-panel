import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for the home panel.
///
/// Every value here maps directly to the design specification: an 8px grid,
/// near-black blue backgrounds, ultra-subtle card gradients, tenuous borders,
/// screen-reflection glows and imperceptible shadows.
class AppColors {
  AppColors._();

  // Background (never pure black — keeps depth).
  static const Color bgTop = Color(0xFF0C1018);
  static const Color bgBottom = Color(0xFF090B10);

  // Card gradient (~3% difference, top-left to bottom-right).
  static const Color cardTop = Color(0xFF181F2C);
  static const Color cardBottom = Color(0xFF121822);

  // Borders — extremely tenuous, never white outlines.
  static const Color border = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)

  // Text hierarchy.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD0D6DE);
  static const Color textTertiary = Color(0xFF98A2B3);

  // Structural.
  static const Color divider = Color(0xFF252F3F);

  // Accents.
  static const Color blue = Color(0xFF4EA6FF);
  static const Color blueBright = Color(0xFF66C0FF);
  static const Color green = Color(0xFF47D764);
  static const Color amber = Color(0xFFFFB31A);
  static const Color violet = Color(0xFF8264FF);

  // Glow — the reflection of a screen, not a neon.
  static const Color glow = Color(0xFF42A5FF);
}

/// 8px grid. Never use arbitrary values.
class AppSpacing {
  AppSpacing._();

  static const double outer = 32; // Exterior padding.
  static const double cardGap = 24; // Separation between cards.
  static const double cardPadding = 28; // Internal card padding.
  static const double titleContent = 20; // Title -> content.
  static const double iconText = 12; // Icon -> text.
  static const double miniGap = 16; // Between small cards.

  static const double s8 = 8;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s40 = 40;
}

class AppRadius {
  AppRadius._();

  static const double main = 26;
  static const double card = 22;
  static const double mini = 18;
  static const double navbar = 28;
  static const double activeButton = 20;
}

class AppMotion {
  AppMotion._();

  static const Duration duration = Duration(milliseconds: 180);
  static const Curve curve = Curves.easeOutCubic;
}

class AppShadows {
  AppShadows._();

  /// Shadows must never be noticed — they only lift cards off the background.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x59000000), // Black 35%.
      blurRadius: 30,
      offset: Offset(0, 12),
    ),
  ];

  /// The screen-reflection glow. Only weather card + active nav button.
  static List<BoxShadow> glow = [
    BoxShadow(
      color: AppColors.glow.withValues(alpha: 0.15),
      blurRadius: 22,
      spreadRadius: 1,
    ),
  ];
}

class AppGradients {
  AppGradients._();

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.bgTop, AppColors.bgBottom],
  );

  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.cardTop, AppColors.cardBottom],
  );
}

/// Typography — Inter (never Roboto). Weights follow the hierarchy spec.
class AppText {
  AppText._();

  static TextStyle _base(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Time — enormous, readable from four meters.
  static TextStyle get time =>
      _base(76, FontWeight.w700, AppColors.textPrimary, height: 1.0, letterSpacing: -1.5);

  static TextStyle get date =>
      _base(16, FontWeight.w500, AppColors.textSecondary);

  static TextStyle get tempHero =>
      _base(44, FontWeight.w700, AppColors.textPrimary, height: 1.0, letterSpacing: -1);

  static TextStyle get tempMedium =>
      _base(30, FontWeight.w700, AppColors.textPrimary, height: 1.0);

  static TextStyle get sectionTitle =>
      _base(20, FontWeight.w600, AppColors.textPrimary);

  static TextStyle get cardTitle =>
      _base(14, FontWeight.w600, AppColors.textSecondary);

  static TextStyle get greeting =>
      _base(28, FontWeight.w600, AppColors.textPrimary, letterSpacing: -0.3);

  static TextStyle get greetingSub =>
      _base(15, FontWeight.w400, AppColors.textTertiary);

  static TextStyle get bodyStrong =>
      _base(18, FontWeight.w600, AppColors.textPrimary);

  static TextStyle get body =>
      _base(15, FontWeight.w500, AppColors.textSecondary);

  static TextStyle get secondary =>
      _base(13, FontWeight.w400, AppColors.textTertiary);

  static TextStyle get chipLabel =>
      _base(13, FontWeight.w600, AppColors.textSecondary);

  static TextStyle get chipValue =>
      _base(12, FontWeight.w400, AppColors.textTertiary);

  static TextStyle get navLabel =>
      _base(12, FontWeight.w500, AppColors.textTertiary);

  static TextStyle get statLabel =>
      _base(12, FontWeight.w400, AppColors.textTertiary);

  static TextStyle get statValue =>
      _base(15, FontWeight.w600, AppColors.textPrimary);
}
