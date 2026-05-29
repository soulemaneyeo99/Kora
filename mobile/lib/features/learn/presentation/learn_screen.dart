import 'package:flutter/material.dart';

import '../../../core/theme/kora_colors.dart';
import '../../../core/theme/kora_spacing.dart';
import '../../../core/theme/kora_typography.dart';

/// Ecran Apprendre (CDC F23) - 6 modules educatifs courts, localises CI.
/// Contenu statique embarque cote app : pas de backend, pas de reseau.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apprendre')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KoraSpacing.pagePadding),
          children: [
            Text('6 modules pour mieux gerer ton argent',
                style: KoraType.h1()),
            const SizedBox(height: KoraSpacing.xs),
            Text(
              'Chaque module se lit en moins de 5 minutes. Va a ton rythme.',
              style: KoraType.body(color: KoraColors.gray),
            ),
            const SizedBox(height: KoraSpacing.lg),
            for (final m in _modules)
              Padding(
                padding: const EdgeInsets.only(bottom: KoraSpacing.sm),
                child: _ModuleTile(module: m),
              ),
          ],
        ),
      ),
    );
  }
}

class _Module {
  const _Module({
    required this.icon,
    required this.title,
    required this.minutes,
    required this.summary,
    required this.body,
  });
  final IconData icon;
  final String title;
  final int minutes;
  final String summary;
  final String body;
}

const _modules = <_Module>[
  _Module(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Connaitre tes revenus',
    minutes: 3,
    summary: 'Salaire, business, transferts : faire le vrai compte.',
    body:
        'En Cote d\'Ivoire, beaucoup de personnes ont 2 ou 3 sources de revenu '
        'mais ne les comptent jamais ensemble. Resultat : on se sous-estime.\n\n'
        '1. Liste TOUTES tes entrees du mois dernier : salaire, petit business, '
        'tontine recue, transferts familiaux, freelance.\n\n'
        '2. Additionne. Tu vas etre surpris(e).\n\n'
        '3. Ce total = ton vrai pouvoir d\'achat. C\'est ce chiffre qui guide '
        'tes decisions, pas seulement ton salaire principal.\n\n'
        'Astuce : note dans KORA chaque petite entree, meme 1 000 FCFA. C\'est '
        'la regularite qui fait la difference.',
  ),
  _Module(
    icon: Icons.shopping_bag_outlined,
    title: 'Maitriser tes depenses',
    minutes: 4,
    summary: 'La methode 50/30/20 adaptee au contexte CI.',
    body:
        'La regle 50/30/20 classique dit : 50% besoins, 30% envies, 20% '
        'epargne. En Cote d\'Ivoire, vu le cout de la vie, on adapte.\n\n'
        '60% pour les besoins : loyer, nourriture, transport, factures.\n'
        '20% pour les envies : sorties, telephone, vetements.\n'
        '20% pour l\'avenir : epargne, projets, urgence.\n\n'
        'Si tu n\'arrives pas au 20% d\'epargne, commence a 5%. C\'est mieux '
        'que rien. L\'important : augmenter chaque mois.\n\n'
        'Repere tes 3 plus grosses categories dans l\'onglet Analyse. C\'est '
        'la que tu peux economiser le plus vite.',
  ),
  _Module(
    icon: Icons.savings_outlined,
    title: 'Construire ton epargne',
    minutes: 4,
    summary: 'Le fonds d\'urgence avant tout autre objectif.',
    body:
        'Premiere etape avant tout autre objectif : un fonds d\'urgence egal '
        'a 1 mois de tes depenses.\n\n'
        'Pourquoi ? Parce que la maladie, la panne de mobylette, le '
        'depannage d\'un proche arrivent toujours. Sans fonds, tu casses tes '
        'autres economies a chaque fois.\n\n'
        'Comment ? La regle "paie-toi en premier" : des que tu touches '
        'ton revenu, mets 10% de cote AVANT meme de payer le loyer.\n\n'
        'Ou ? Un compte epargne mobile money separe de ton compte principal. '
        'Ou un pot KORA dedie : c\'est psychologiquement plus difficile a '
        'casser.\n\n'
        'Defi : tente d\'atteindre 50 000 FCFA en 6 mois. Apres, tu seras '
        'beaucoup plus serein(e).',
  ),
  _Module(
    icon: Icons.flag_outlined,
    title: 'Fixer des objectifs SMART',
    minutes: 3,
    summary: 'Un objectif flou ne s\'atteint jamais.',
    body:
        'Un objectif "epargner pour plus tard" ne marche pas. Le cerveau a '
        'besoin de precision.\n\n'
        'SMART = :\n'
        'S - Specifique : "Acheter une moto Bajaj"\n'
        'M - Mesurable : "650 000 FCFA"\n'
        'A - Atteignable : tu peux mettre 50 000 / mois ? OK.\n'
        'R - Realiste : pas un avion en 6 mois\n'
        'T - Temporel : "d\'ici 13 mois"\n\n'
        'Decoupe : 650 000 / 13 = 50 000 / mois = 1 666 / jour.\n\n'
        'Maintenant chaque jour tu sais si tu es en avance ou en retard. C\'est '
        'ca, un objectif qui se realise.\n\n'
        'Cree ton premier objectif dans l\'onglet Objectifs.',
  ),
  _Module(
    icon: Icons.phone_iphone_outlined,
    title: 'Maitriser le mobile money',
    minutes: 4,
    summary: 'Frais caches, securite, bons reflexes Wave / OM / MoMo.',
    body:
        'Le mobile money est un outil incroyable mais il a des pieges.\n\n'
        '1. Connais tes frais : chaque operateur affiche son bareme. '
        'Verifie avant chaque gros transfert. Sur 1 an, ca fait des dizaines '
        'de milliers de FCFA.\n\n'
        '2. Privilegie Wave pour les transferts inter-personnes (souvent '
        'gratuit ou tres bas), OM/MoMo pour les paiements marchands.\n\n'
        '3. Ne donne JAMAIS ton code secret. Aucun agent, aucun service '
        'client legitime ne te le demandera. KORA ne le demande pas non plus.\n\n'
        '4. Active le verrouillage biometrique de ton telephone et de tes '
        'apps mobile money.\n\n'
        '5. Note chaque transaction dans KORA. C\'est ton historique '
        'independant en cas de probleme.',
  ),
  _Module(
    icon: Icons.psychology_outlined,
    title: 'Sortir des pieges psychologiques',
    minutes: 5,
    summary: 'L\'argent est emotionnel avant d\'etre rationnel.',
    body:
        'Tu sais qu\'il faut epargner mais tu n\'y arrives pas ? C\'est '
        'normal. L\'argent active le meme cerveau que la nourriture et la '
        'survie. Voici 5 pieges classiques :\n\n'
        '1. L\'effet de halo : tu as recu un revenu exceptionnel, tu te '
        'sens riche, tu depenses 30% sur le coup. PARADE : mets 80% au '
        'pot le jour meme.\n\n'
        '2. La pression sociale : famille, amis, ceremonies. PARADE : '
        'budget mensuel "social" fixe, tu ne depasses pas.\n\n'
        '3. Les achats emotionnels : stress, fatigue, ennui. PARADE : '
        'regle des 24h. Tu attends 24h avant tout achat > 5 000 FCFA non '
        'prevu.\n\n'
        '4. Le "je merite" apres un coup dur. C\'est legitime mais '
        'fixe-toi une enveloppe limitee.\n\n'
        '5. Comparer aux autres sur les reseaux. PARADE : compare-toi a '
        'toi-meme du mois dernier. C\'est la seule comparaison utile.',
  ),
];

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});
  final _Module module;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(KoraSpacing.radiusLg),
        onTap: () => _openModule(context),
        child: Padding(
          padding: const EdgeInsets.all(KoraSpacing.cardPadding),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: KoraColors.greenPale,
                  shape: BoxShape.circle,
                ),
                child: Icon(module.icon, color: KoraColors.greenPrimary),
              ),
              const SizedBox(width: KoraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.title, style: KoraType.bodyStrong()),
                    Text(module.summary, style: KoraType.caption()),
                    Text('${module.minutes} min de lecture',
                        style: KoraType.caption(color: KoraColors.greenActive)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: KoraColors.gray),
            ],
          ),
        ),
      ),
    );
  }

  void _openModule(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ModuleDetailScreen(module: module),
      ),
    );
  }
}

class _ModuleDetailScreen extends StatelessWidget {
  const _ModuleDetailScreen({required this.module});
  final _Module module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(module.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KoraSpacing.pagePadding),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: KoraColors.greenPale,
                shape: BoxShape.circle,
              ),
              child: Icon(module.icon,
                  color: KoraColors.greenPrimary, size: 32),
            ),
            const SizedBox(height: KoraSpacing.md),
            Text(module.title, style: KoraType.h1()),
            Text('${module.minutes} min de lecture',
                style: KoraType.caption(color: KoraColors.greenActive)),
            const SizedBox(height: KoraSpacing.lg),
            Text(module.body, style: KoraType.body()),
            const SizedBox(height: KoraSpacing.xl),
            Card(
              color: KoraColors.greenPale,
              child: Padding(
                padding: const EdgeInsets.all(KoraSpacing.cardPadding),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: KoraColors.greenPrimary),
                    const SizedBox(width: KoraSpacing.sm),
                    Expanded(
                      child: Text(
                        'Mets en pratique dans KORA aujourd\'hui : meme une '
                        'petite action vaut mieux qu\'une grande intention.',
                        style: KoraType.body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
