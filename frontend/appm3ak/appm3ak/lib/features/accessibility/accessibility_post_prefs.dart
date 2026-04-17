import 'package:shared_preferences/shared_preferences.dart';

/// Raccourci quand on appuie sur « créer un post » (communauté ou ouverture auto du formulaire).
enum PostCreationShortcut {
  /// Écran de création habituel (tactile / clavier / vocal puis validation).
  form,

  /// Caméra + ML Kit : tête & yeux (handicap moteur lourd).
  headGesture,

  /// Menu codé par vibrations (ex. sourd-aveugle).
  vibration,

  /// Dictée vocale + vibrations + validation au dos.
  voiceVibration,
}

/// Préférences locales pour l’accès aux posts sans toucher l’écran du formulaire.
class AccessibilityPostPrefs {
  AccessibilityPostPrefs._();

  static const _keyShortcut = 'post_creation_shortcut_v1';
  static const _keyLegacyHead = 'open_head_gesture_first_for_posts';

  static PostCreationShortcut _parseShortcut(String? raw) {
    if (raw == null || raw.isEmpty) return PostCreationShortcut.form;
    for (final e in PostCreationShortcut.values) {
      if (e.name == raw) return e;
    }
    return PostCreationShortcut.form;
  }

  /// Raccourci pour le bouton + et l’ouverture auto du formulaire (hors web).
  static Future<PostCreationShortcut> getPostCreationShortcut() async {
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_keyShortcut);
    if (stored != null) {
      return _parseShortcut(stored);
    }
    if (p.getBool(_keyLegacyHead) == true) {
      await p.setString(_keyShortcut, PostCreationShortcut.headGesture.name);
      return PostCreationShortcut.headGesture;
    }
    return PostCreationShortcut.form;
  }

  static Future<void> setPostCreationShortcut(PostCreationShortcut value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyShortcut, value.name);
    await p.setBool(
      _keyLegacyHead,
      value == PostCreationShortcut.headGesture,
    );
  }

}
