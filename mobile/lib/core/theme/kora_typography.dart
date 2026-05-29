import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kora_colors.dart';

/// Typographie KORA (Charte chapitre 3) : Poppins pour les titres et
/// l'identité de marque, Inter pour le corps et les chiffres financiers.
///
/// google_fonts récupère et met en cache les polices au runtime (elles
/// pourront être bundlées plus tard pour le mode offline strict).
abstract final class KoraType {
  KoraType._();

  // ---- Poppins (marque / titres) -----------------------------------------
  static TextStyle h1({Color color = KoraColors.night}) => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: color,
      );

  static TextStyle h2({Color color = KoraColors.night}) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle sectionTitle({Color color = KoraColors.night}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle cardLabel({Color color = KoraColors.night}) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle buttonLabel({Color color = KoraColors.white}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Wordmark "FINANCE" : Poppins Light très espacé.
  static TextStyle wordmarkLight({Color color = KoraColors.greenLight}) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w300,
        letterSpacing: 6,
        color: color,
      );

  // ---- Inter (interface / chiffres) --------------------------------------
  /// Grande statistique (montant principal), Inter SemiBold.
  static TextStyle moneyLarge({Color color = KoraColors.greenPrimary}) =>
      GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle moneyMedium({Color color = KoraColors.greenPrimary}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle body({Color color = KoraColors.night}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyStrong({Color color = KoraColors.night}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle caption({Color color = KoraColors.gray}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle fieldLabel({Color color = KoraColors.gray}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// TextTheme Material complet (utilisé par ThemeData).
  static TextTheme textTheme(Color onSurface) => TextTheme(
        displaySmall: h1(color: onSurface),
        headlineMedium: h2(color: onSurface),
        titleLarge: sectionTitle(color: onSurface),
        titleMedium: cardLabel(color: onSurface),
        bodyLarge: body(color: onSurface),
        bodyMedium: body(color: onSurface),
        bodySmall: caption(),
        labelLarge: buttonLabel(),
      );
}
