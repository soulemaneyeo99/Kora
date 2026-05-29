/// Tranche de revenus declaree a l'onboarding (CDC F02).
enum IncomeBracket {
  under80k,
  k80_150,
  k150_300,
  over300k;

  String get apiValue => switch (this) {
        IncomeBracket.under80k => 'under_80k',
        IncomeBracket.k80_150 => 'k80_150',
        IncomeBracket.k150_300 => 'k150_300',
        IncomeBracket.over300k => 'over_300k',
      };

  String get label => switch (this) {
        IncomeBracket.under80k => 'Moins de 80 000 FCFA',
        IncomeBracket.k80_150 => '80 000 - 150 000 FCFA',
        IncomeBracket.k150_300 => '150 000 - 300 000 FCFA',
        IncomeBracket.over300k => 'Plus de 300 000 FCFA',
      };

  static IncomeBracket? fromApi(String? v) => switch (v) {
        'under_80k' => IncomeBracket.under80k,
        'k80_150' => IncomeBracket.k80_150,
        'k150_300' => IncomeBracket.k150_300,
        'over_300k' => IncomeBracket.over300k,
        _ => null,
      };
}

/// Objectif principal declare (CDC F02).
enum PrimaryGoal {
  save,
  payBills,
  buy,
  business;

  String get apiValue => switch (this) {
        PrimaryGoal.save => 'save',
        PrimaryGoal.payBills => 'pay_bills',
        PrimaryGoal.buy => 'buy',
        PrimaryGoal.business => 'business',
      };

  String get label => switch (this) {
        PrimaryGoal.save => 'Epargner',
        PrimaryGoal.payBills => 'Payer mes factures',
        PrimaryGoal.buy => 'Acheter quelque chose',
        PrimaryGoal.business => 'Lancer ou grossir un business',
      };

  String get emoji => switch (this) {
        PrimaryGoal.save => '💰',
        PrimaryGoal.payBills => '🧾',
        PrimaryGoal.buy => '🎁',
        PrimaryGoal.business => '🚀',
      };

  static PrimaryGoal? fromApi(String? v) => switch (v) {
        'save' => PrimaryGoal.save,
        'pay_bills' => PrimaryGoal.payBills,
        'buy' => PrimaryGoal.buy,
        'business' => PrimaryGoal.business,
        _ => null,
      };
}

/// Utilisateur KORA tel que renvoye par le backend (UserPublic).
class KoraUser {
  const KoraUser({
    required this.id,
    required this.phoneE164,
    this.displayName,
    this.locale = 'fr',
    this.incomeBracket,
    this.primaryGoal,
    this.hasCompletedOnboarding = false,
  });

  final String id;
  final String phoneE164;
  final String? displayName;
  final String locale;
  final IncomeBracket? incomeBracket;
  final PrimaryGoal? primaryGoal;
  final bool hasCompletedOnboarding;

  String get greetingName =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'champion';

  KoraUser copyWith({
    String? displayName,
    IncomeBracket? incomeBracket,
    PrimaryGoal? primaryGoal,
    bool? hasCompletedOnboarding,
  }) =>
      KoraUser(
        id: id,
        phoneE164: phoneE164,
        displayName: displayName ?? this.displayName,
        locale: locale,
        incomeBracket: incomeBracket ?? this.incomeBracket,
        primaryGoal: primaryGoal ?? this.primaryGoal,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      );

  factory KoraUser.fromJson(Map<String, dynamic> json) => KoraUser(
        id: json['id'] as String,
        phoneE164: json['phone_e164'] as String,
        displayName: json['display_name'] as String?,
        locale: (json['locale'] as String?) ?? 'fr',
        incomeBracket: IncomeBracket.fromApi(json['income_bracket'] as String?),
        primaryGoal: PrimaryGoal.fromApi(json['primary_goal'] as String?),
        hasCompletedOnboarding:
            json['has_completed_onboarding'] as bool? ?? false,
      );
}
