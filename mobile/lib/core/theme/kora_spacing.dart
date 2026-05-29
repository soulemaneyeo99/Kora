/// Grille de base 4dp (Charte Graphique V1.0, chapitre 5).
///
/// Tous les espacements sont des multiples de 4. Les rayons suivent
/// radius-md (8), radius-lg (12), radius-xl (16).
abstract final class KoraSpacing {
  KoraSpacing._();

  static const double micro = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // marge latérale standard des pages
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  // Rayons de coins
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  // Composants
  static const double pagePadding = 16;
  static const double cardPadding = 16;
  static const double buttonHeight = 56; // CTA principaux (Material 3)
  static const double fieldHeight = 56;
  static const double navBarHeight = 56;
  static const double appBarHeight = 64;

  // Barres de progression
  static const double progressHeightCompact = 8;
  static const double progressHeightProminent = 12;
}
