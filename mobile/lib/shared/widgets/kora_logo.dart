import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/kora_colors.dart';
import '../../core/theme/kora_spacing.dart';

/// Logo KORA (Charte chapitre 1).
///
/// Le pictogramme utilise l'icône officielle (`assets/images/logo_kora.jpeg`).
/// Le wordmark "KORA / FINANCE" est reconstruit en Poppins (Bold / Light)
/// pour rester net à toutes les tailles.
class KoraLogo extends StatelessWidget {
  const KoraLogo({super.key, this.size = 56, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/logo_kora.jpeg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: KoraSpacing.sm),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KORA',
              style: GoogleFonts.poppins(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: KoraColors.greenPrimary,
              ),
            ),
            Text(
              'FINANCE',
              style: GoogleFonts.poppins(
                fontSize: size * 0.16,
                fontWeight: FontWeight.w300,
                letterSpacing: 5,
                color: KoraColors.gray,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
