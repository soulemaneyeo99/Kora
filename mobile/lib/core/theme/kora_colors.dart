import 'package:flutter/material.dart';

/// Palette officielle KORA Finance (Charte Graphique V1.0, chapitre 2).
///
/// Le vert = argent/croissance, l'or = récompense/objectif atteint.
/// Contrastes calibrés WCAG 2.1 AA pour écrans entrée de gamme au soleil.
abstract final class KoraColors {
  KoraColors._();

  // ---- Couleurs primaires -------------------------------------------------
  /// Couleur identitaire #1. Logo, boutons principaux, headers, liens.
  static const Color greenPrimary = Color(0xFF0F6E56);

  /// Couleur identitaire #2. Hover, barres de progression, cercle du logo K.
  static const Color greenActive = Color(0xFF1D9E75);

  /// Accent. Badges, récompenses, objectifs atteints, CTA secondaires.
  static const Color gold = Color(0xFFEF9F27);

  // ---- Couleurs secondaires ----------------------------------------------
  /// Fond principal dark mode / texte principal sur fond clair.
  static const Color night = Color(0xFF1A1A18);

  /// Cards dark mode, navbars, zones secondaires sombres.
  static const Color charcoal = Color(0xFF2C2C2A);

  /// Fond principal light mode, fond des documents.
  static const Color cream = Color(0xFFF5F5F0);

  /// Textes secondaires, labels, placeholders, dates.
  static const Color gray = Color(0xFF888780);

  // ---- Couleurs d'état & sémantiques --------------------------------------
  /// Texte clair sur fond vert foncé, tagline du logo, succès léger.
  static const Color greenLight = Color(0xFFA8DECE);

  /// Fond des encadrés info verts / sections succès légères.
  static const Color greenPale = Color(0xFFE8F5F0);

  /// Fond des alertes positives / récompenses.
  static const Color goldPale = Color(0xFFFEF6E0);

  /// Alertes critiques UNIQUEMENT — usage très limité.
  static const Color red = Color(0xFFC0392B);

  // ---- Neutres utilitaires ------------------------------------------------
  static const Color white = Color(0xFFFFFFFF);

  /// Bordure des cards en light mode (0.5px solid).
  static const Color borderLight = Color(0xFFDEDCD4);

  /// Bordure des cards en dark mode.
  static const Color borderDark = Color(0xFF444441);

  /// Fond des cards metric/stat en light mode.
  static const Color surfaceLight = Color(0xFFF4F4F0);

  // ---- Couleurs des 11 catégories de dépenses (charte 4.2) ----------------
  static const Map<String, Color> categoryColors = <String, Color>{
    'Logement': Color(0xFF1A5276),
    'Alimentation': Color(0xFF27AE60),
    'Transport': Color(0xFF2E86C1),
    'Famille': Color(0xFFF1C40F),
    'Village': Color(0xFF784212),
    'Loisirs': Color(0xFFE91E8C),
    'Santé': Color(0xFFC0392B),
    'Éducation': Color(0xFF8E44AD),
    'Business': Color(0xFF566573),
    'Télécom': Color(0xFF1ABC9C),
    'Épargne': greenPrimary,
  };
}
