/// Utilisateur KORA tel que renvoyé par le backend (UserPublic).
class KoraUser {
  const KoraUser({
    required this.id,
    required this.phoneE164,
    this.displayName,
    this.locale = 'fr',
  });

  final String id;
  final String phoneE164;
  final String? displayName;
  final String locale;

  /// Prénom à afficher dans les messages du coach ("Bienvenue Konan !").
  String get greetingName =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : 'champion';

  factory KoraUser.fromJson(Map<String, dynamic> json) => KoraUser(
        id: json['id'] as String,
        phoneE164: json['phone_e164'] as String,
        displayName: json['display_name'] as String?,
        locale: (json['locale'] as String?) ?? 'fr',
      );
}
