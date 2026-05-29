import 'package:flutter/material.dart';

import 'kora_colors.dart';
import 'kora_spacing.dart';
import 'kora_typography.dart';

/// ThemeData KORA — light & dark (Charte chapitres 2-5).
///
/// Design "flat" : cards sans ombre, bordures fines, coins arrondis 12dp.
abstract final class KoraTheme {
  KoraTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: KoraColors.greenPrimary,
      onPrimary: KoraColors.white,
      secondary: KoraColors.gold,
      onSecondary: KoraColors.night,
      tertiary: KoraColors.greenActive,
      onTertiary: KoraColors.white,
      error: KoraColors.red,
      onError: KoraColors.white,
      surface: KoraColors.white,
      onSurface: KoraColors.night,
      surfaceContainerLowest: KoraColors.cream,
      surfaceContainerLow: KoraColors.surfaceLight,
      outline: KoraColors.borderLight,
      outlineVariant: KoraColors.borderLight,
    );

    return _base(scheme, KoraColors.cream);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: KoraColors.greenActive,
      onPrimary: KoraColors.white,
      secondary: KoraColors.gold,
      onSecondary: KoraColors.night,
      tertiary: KoraColors.greenLight,
      onTertiary: KoraColors.night,
      error: KoraColors.red,
      onError: KoraColors.white,
      surface: KoraColors.charcoal,
      onSurface: KoraColors.cream,
      surfaceContainerLowest: KoraColors.night,
      surfaceContainerLow: KoraColors.charcoal,
      outline: KoraColors.borderDark,
      outlineVariant: KoraColors.borderDark,
    );

    return _base(scheme, KoraColors.night);
  }

  static ThemeData _base(ColorScheme scheme, Color scaffoldBg) {
    final radiusLg = BorderRadius.circular(KoraSpacing.radiusLg);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: KoraType.textTheme(scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: KoraSpacing.appBarHeight,
        titleTextStyle: KoraType.h2(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radiusLg,
          side: BorderSide(color: scheme.outline, width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(KoraSpacing.buttonHeight),
          textStyle: KoraType.buttonLabel(),
          shape: RoundedRectangleBorder(borderRadius: radiusLg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(KoraSpacing.buttonHeight),
          side: BorderSide(color: scheme.primary),
          textStyle: KoraType.buttonLabel(color: scheme.primary),
          shape: RoundedRectangleBorder(borderRadius: radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KoraSpacing.md,
          vertical: KoraSpacing.md,
        ),
        labelStyle: KoraType.fieldLabel(),
        hintStyle: KoraType.body(color: KoraColors.gray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KoraSpacing.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: KoraColors.greenPale,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(KoraType.fieldLabel()),
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.primary,
        contentTextStyle: KoraType.body(color: KoraColors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
