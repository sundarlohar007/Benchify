import 'dart:io' show Platform;

import 'package:flutter/material.dart';

// =============================================================================
// Design Tokens — UNIFIED-SPEC §9.1.1 Color Palette, §9.1.2 Typography
// All colors, sizes, and spacing MUST be consumed via Theme.of(context).
// Never hardcode hex colors in widgets — use AppColors.of(context).<token>.
// =============================================================================

/// Per-metric chart colors — consistent across all screens (§9.1.1).
class ChartColors {
  static const Color fps = Color(0xFF569CD6);
  static const Color cpuApp = Color(0xFF4EC9B0);
  static const Color cpuSystem = Color(0xFF4EC9B0);
  static const Color cpuSystemDim = Color(0x604EC9B0);
  static const Color memory = Color(0xFFCE9178);
  static const Color batteryPct = Color(0xFFDCDCAA);
  static const Color batteryMa = Color(0xFFC586C0);
  static const Color batteryMv = Color(0xFF9CDCFE);
  static const Color batteryTemp = Color(0xFFF44747);
  static const Color networkTx = Color(0xFF4FC1FF);
  static const Color networkRx = Color(0xFF85C1E9);
  static const Color gpu = Color(0xFFC586C0);

  /// Thermal color mapping: status 0→green, 1→orange, 2→red, 3→bright red
  static Color thermalStatus(int status) {
    switch (status) {
      case 0:
        return const Color(0xFF4EC9B0);
      case 1:
        return const Color(0xFFCE9178);
      case 2:
        return const Color(0xFFF44747);
      case 3:
        return const Color(0xFFFF0000);
      default:
        return const Color(0xFF4EC9B0);
    }
  }

  /// Fill gradient start values (same colors at roughly 20% opacity)
  static const Map<String, Color> fillStarts = {
    'FPS': Color(0x20569CD6),
    'CPU_App': Color(0x204EC9B0),
    'CPU_System': Color(0x104EC9B0),
    'Memory': Color(0x20CE9178),
    'Battery_pct': Color(0x20DCDCAA),
    'Battery_mA': Color(0x20C586C0),
    'Battery_mV': Color(0x209CDCFE),
    'Battery_Temp': Color(0x20F44747),
    'Network_TX': Color(0x204FC1FF),
    'Network_RX': Color(0x2085C1E9),
    'GPU': Color(0x20C586C0),
  };
}

/// Design token extension — add to ThemeData.extensions for
/// `Theme.of(context).extension<AppColors>()` access.
class AppColors extends ThemeExtension<AppColors> {
  // Background layers
  final Color bgBase;
  final Color bgSidebar;
  final Color bgElevated;
  final Color bgHover;
  final Color bgSelected;
  final Color bgInput;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textAccent;

  // Borders
  final Color borderSubtle;
  final Color borderFocus;

  // Accent & State
  final Color accentBlue;
  final Color accentRecording;
  final Color accentSuccess;
  final Color accentWarning;
  final Color accentDanger;
  final Color accentGold;

  const AppColors({
    required this.bgBase,
    required this.bgSidebar,
    required this.bgElevated,
    required this.bgHover,
    required this.bgSelected,
    required this.bgInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textAccent,
    required this.borderSubtle,
    required this.borderFocus,
    required this.accentBlue,
    required this.accentRecording,
    required this.accentSuccess,
    required this.accentWarning,
    required this.accentDanger,
    required this.accentGold,
  });

  /// VS Code Dark+ palette (default).
  static const dark = AppColors(
    bgBase: Color(0xFF1E1E1E),
    bgSidebar: Color(0xFF252526),
    bgElevated: Color(0xFF2D2D30),
    bgHover: Color(0xFF2A2D2E),
    bgSelected: Color(0xFF094771),
    bgInput: Color(0xFF3C3C3C),
    textPrimary: Color(0xFFD4D4D4),
    textSecondary: Color(0xFF858585),
    textDisabled: Color(0xFF5A5A5A),
    textAccent: Color(0xFF4FC3F7),
    borderSubtle: Color(0xFF3C3C3C),
    borderFocus: Color(0xFF007ACC),
    accentBlue: Color(0xFF007ACC),
    accentRecording: Color(0xFFF44747),
    accentSuccess: Color(0xFF4EC9B0),
    accentWarning: Color(0xFFCE9178),
    accentDanger: Color(0xFFF44747),
    accentGold: Color(0xFFDCDCAA),
  );

  /// Light theme inversions (D-14).
  static const light = AppColors(
    bgBase: Color(0xFFFFFFFF),
    bgSidebar: Color(0xFFF3F3F3),
    bgElevated: Color(0xFFECECEC),
    bgHover: Color(0xFFE8E8E8),
    bgSelected: Color(0xFFD6EBFF),
    bgInput: Color(0xFFDDDDDD),
    textPrimary: Color(0xFF1E1E1E),
    textSecondary: Color(0xFF717171),
    textDisabled: Color(0xFFA0A0A0),
    textAccent: Color(0xFF007ACC),
    borderSubtle: Color(0xFFCCCCCC),
    borderFocus: Color(0xFF007ACC),
    accentBlue: Color(0xFF007ACC),
    accentRecording: Color(0xFFD32F2F),
    accentSuccess: Color(0xFF388E3C),
    accentWarning: Color(0xFFE65100),
    accentDanger: Color(0xFFD32F2F),
    accentGold: Color(0xFF9E8C00),
  );

  /// High contrast theme (D-14).
  static const highContrast = AppColors(
    bgBase: Color(0xFF000000),
    bgSidebar: Color(0xFF0A0A0A),
    bgElevated: Color(0xFF151515),
    bgHover: Color(0xFF1A1A1A),
    bgSelected: Color(0xFF003D6B),
    bgInput: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFBBBBBB),
    textDisabled: Color(0xFF666666),
    textAccent: Color(0xFFFFFF00),
    borderSubtle: Color(0xFF555555),
    borderFocus: Color(0xFFFFFF00),
    accentBlue: Color(0xFFFFFF00),
    accentRecording: Color(0xFFFF4444),
    accentSuccess: Color(0xFF44FF44),
    accentWarning: Color(0xFFFFAA00),
    accentDanger: Color(0xFFFF4444),
    accentGold: Color(0xFFFFDD44),
  );

  @override
  AppColors copyWith({
    Color? bgBase,
    Color? bgSidebar,
    Color? bgElevated,
    Color? bgHover,
    Color? bgSelected,
    Color? bgInput,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textAccent,
    Color? borderSubtle,
    Color? borderFocus,
    Color? accentBlue,
    Color? accentRecording,
    Color? accentSuccess,
    Color? accentWarning,
    Color? accentDanger,
    Color? accentGold,
  }) {
    return AppColors(
      bgBase: bgBase ?? this.bgBase,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      bgElevated: bgElevated ?? this.bgElevated,
      bgHover: bgHover ?? this.bgHover,
      bgSelected: bgSelected ?? this.bgSelected,
      bgInput: bgInput ?? this.bgInput,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textAccent: textAccent ?? this.textAccent,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderFocus: borderFocus ?? this.borderFocus,
      accentBlue: accentBlue ?? this.accentBlue,
      accentRecording: accentRecording ?? this.accentRecording,
      accentSuccess: accentSuccess ?? this.accentSuccess,
      accentWarning: accentWarning ?? this.accentWarning,
      accentDanger: accentDanger ?? this.accentDanger,
      accentGold: accentGold ?? this.accentGold,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgBase: Color.lerp(bgBase, other.bgBase, t)!,
      bgSidebar: Color.lerp(bgSidebar, other.bgSidebar, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgHover: Color.lerp(bgHover, other.bgHover, t)!,
      bgSelected: Color.lerp(bgSelected, other.bgSelected, t)!,
      bgInput: Color.lerp(bgInput, other.bgInput, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textAccent: Color.lerp(textAccent, other.textAccent, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentRecording:
          Color.lerp(accentRecording, other.accentRecording, t)!,
      accentSuccess: Color.lerp(accentSuccess, other.accentSuccess, t)!,
      accentWarning: Color.lerp(accentWarning, other.accentWarning, t)!,
      accentDanger: Color.lerp(accentDanger, other.accentDanger, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
    );
  }

  /// Convenience accessor.
  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? AppColors.dark;
  }
}

/// Monospace font family — resolved at runtime by platform (§9.1.2).
String monoFontFamily() {
  if (Platform.isWindows) return 'Cascadia Code';
  if (Platform.isMacOS) return 'SF Mono';
  return 'JetBrainsMono'; // Linux + fallback
}

/// Typography scale tokens (§9.1.2).
class TextTokens {
  static const double xs = 10.0;
  static const double sm = 11.0;
  static const double base = 13.0;
  static const double md = 14.0;
  static const double lg = 20.0;
  static const double xl = 28.0;
  static const double monoValue = 16.0;
  static const double monoSm = 12.0;
}

// =============================================================================
// ThemeData Factories
// =============================================================================

/// Dark+ theme (VS Code default dark — D-14).
ThemeData darkTheme() {
  const colors = AppColors.dark;
  return _buildTheme(
    brightness: Brightness.dark,
    colors: colors,
    scaffoldBg: colors.bgBase,
    appBarBg: colors.bgSidebar,
    cardBg: colors.bgElevated,
    dividerColor: colors.borderSubtle,
    hintColor: colors.textDisabled,
  );
}

/// Light theme (D-14).
ThemeData lightTheme() {
  const colors = AppColors.light;
  return _buildTheme(
    brightness: Brightness.light,
    colors: colors,
    scaffoldBg: colors.bgBase,
    appBarBg: colors.bgSidebar,
    cardBg: colors.bgElevated,
    dividerColor: colors.borderSubtle,
    hintColor: colors.textDisabled,
  );
}

/// High contrast theme (D-14).
ThemeData highContrastTheme() {
  const colors = AppColors.highContrast;
  return _buildTheme(
    brightness: Brightness.dark,
    colors: colors,
    scaffoldBg: colors.bgBase,
    appBarBg: colors.bgSidebar,
    cardBg: colors.bgElevated,
    dividerColor: colors.borderSubtle,
    hintColor: colors.textDisabled,
  );
}

/// System theme — delegates to platform brightness (D-14).
ThemeData systemTheme({required Brightness brightness}) {
  if (brightness == Brightness.dark) return darkTheme();
  return lightTheme();
}

ThemeData _buildTheme({
  required Brightness brightness,
  required AppColors colors,
  required Color scaffoldBg,
  required Color appBarBg,
  required Color cardBg,
  required Color dividerColor,
  required Color hintColor,
}) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.accentBlue,
    onPrimary: brightness == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFFFFFFFF),
    secondary: colors.accentSuccess,
    onSecondary: const Color(0xFF000000),
    error: colors.accentDanger,
    onError: const Color(0xFFFFFFFF),
    surface: colors.bgElevated,
    onSurface: colors.textPrimary,
    surfaceContainerHighest: colors.bgInput,
    shadow: colors.borderSubtle,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: dividerColor, width: 0.5),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.bgInput,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.borderFocus),
      ),
      hintStyle: TextStyle(
        color: hintColor,
        fontSize: TextTokens.sm,
      ),
      isDense: true,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.textPrimary,
      unselectedLabelColor: colors.textSecondary,
      indicatorColor: colors.accentBlue,
      dividerColor: dividerColor,
      labelStyle: const TextStyle(
        fontSize: TextTokens.sm,
        fontWeight: FontWeight.w400,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: TextTokens.sm,
        fontWeight: FontWeight.w400,
      ),
    ),
    extensions: [colors],
  );
}
