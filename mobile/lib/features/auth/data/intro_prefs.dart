import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final introPrefsProvider = Provider<IntroPrefs>((ref) => IntroPrefs());

/// Persiste le flag "l'utilisateur a vu l'intro" (3 slides + bouton demo).
class IntroPrefs {
  static const _kIntroSeen = 'kora.intro.seen';

  Future<bool> isIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIntroSeen) ?? false;
  }

  Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIntroSeen, true);
  }
}
