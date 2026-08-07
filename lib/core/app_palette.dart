import 'package:flutter/material.dart';

/// Bottom system-bar inset, clamped to a sane range.
///
/// On some OEM builds `MediaQuery.viewPaddingOf(...).bottom` can briefly
/// report a wildly inflated value right after the app locks its orientation
/// during the splash -> home transition (real gesture/3-button nav bars are
/// never taller than ~48dp). Anything above that is treated as bogus so a
/// stray reading can never push our bottom bars away from the real edge of
/// the screen.
double safeBottomInset(BuildContext context, {double max = 40}) {
  return MediaQuery.viewPaddingOf(context).bottom.clamp(0.0, max);
}

/// Colours, gradients and shared text styles for the Aether look.
class AetherColors {
  const AetherColors._();

  static const night = Color(0xFF071233);
  static const deep = Color(0xFF0B1B45);
  static const dusk = Color(0xFF122A63);
  static const azure = Color(0xFF2E7BFF);
  static const sky = Color(0xFF48A9FF);
  static const electric = Color(0xFF7FD9FF);
  static const gold = Color(0xFFF5C86A);
  static const goldLight = Color(0xFFFFE1A8);
  static const ivory = Color(0xFFF2F6FF);
  static const muted = Color(0xFF9EB2DC);
  static const rose = Color(0xFFFF7BA8);
  static const violet = Color(0xFF9C7BFF);
  static const mint = Color(0xFF6FE3C4);

  // Evening Discharge palette: deep indigo with a violet moon-glow, kept
  // apart from the sky/gold morning look used everywhere else.
  static const nightIndigo = Color(0xFF1A1A2E);
  static const duskIndigo = Color(0xFF232244);
  static const moonViolet = Color(0xFF7C4DFF);
  static const moonGlow = Color(0xFFE4D9FF);

  static const nightBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12122A), Color(0xFF1A1A2E), Color(0xFF201B3E), Color(0xFF141428)],
    stops: [0.0, 0.4, 0.72, 1.0],
  );

  static const backdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF071233), Color(0xFF0A1A44), Color(0xFF0D2455), Color(0xFF071233)],
    stops: [0.0, 0.38, 0.72, 1.0],
  );

  static const glassFill = Color(0x14FFFFFF);
  static const glassStroke = Color(0x33FFFFFF);
}

/// Gradient palettes used by the generated visual collage cards.
class CollagePalette {
  const CollagePalette(this.colors, this.accent, this.ink);

  final List<Color> colors;
  final Color accent;
  final Color ink;

  static const List<CollagePalette> all = [
    CollagePalette(
      [Color(0xFF12327A), Color(0xFF2E7BFF), Color(0xFF7FD9FF)],
      AetherColors.goldLight,
      Colors.white,
    ),
    CollagePalette(
      [Color(0xFF3A1E6E), Color(0xFF7A3BC0), Color(0xFFF07BB0)],
      Color(0xFFFFE8B0),
      Colors.white,
    ),
    CollagePalette(
      [Color(0xFF0B3B4A), Color(0xFF11837F), Color(0xFF6FE3C4)],
      Color(0xFFFFF3C4),
      Colors.white,
    ),
    CollagePalette(
      [Color(0xFF5A1E2C), Color(0xFFB8452F), Color(0xFFF2A65A)],
      Color(0xFFFFF0D0),
      Colors.white,
    ),
    CollagePalette(
      [Color(0xFF10203F), Color(0xFF31518C), Color(0xFF9FB8E8)],
      AetherColors.gold,
      Colors.white,
    ),
    CollagePalette(
      [Color(0xFF4A1140), Color(0xFFC03B79), Color(0xFFFF9EC4)],
      Color(0xFFFFF1DA),
      Colors.white,
    ),
  ];

  static CollagePalette at(int index) => all[index.abs() % all.length];
}

ThemeData buildAetherTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AetherColors.night,
    colorScheme: const ColorScheme.dark(
      primary: AetherColors.sky,
      secondary: AetherColors.gold,
      surface: AetherColors.deep,
      onSurface: AetherColors.ivory,
    ),
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: AetherColors.ivory,
      displayColor: AetherColors.ivory,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AetherColors.dusk,
      contentTextStyle: TextStyle(color: AetherColors.ivory, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AetherColors.glassFill,
      hintStyle: const TextStyle(color: AetherColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AetherColors.glassStroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AetherColors.glassStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AetherColors.sky, width: 1.6),
      ),
    ),
  );
}
