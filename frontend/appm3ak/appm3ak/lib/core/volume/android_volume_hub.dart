import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// Un seul [MethodChannel] Android pour volume+ : priorité au menu vibrations,
/// sinon raccourci « Demandes d’aide ».
class AndroidVolumeHub {
  AndroidVolumeHub._();

  static const MethodChannel _channel =
      MethodChannel('com.appm3ak.appm3ak/volume');

  static bool _initialized = false;

  /// Retourne `true` si l’événement est consommé (ne pas lancer l’action Aides).
  static Future<bool> Function()? onVolumeUpPriority;

  /// Envoi rapide depuis l’onglet Demandes d’aide (sans menu vibrations actif).
  static Future<void> Function()? onVolumeUpHelpTab;

  static Future<void> _dispatch(MethodCall call) async {
    if (call.method != 'volumeUp') return;
    final priority = onVolumeUpPriority;
    if (priority != null) {
      try {
        final consumed = await priority();
        if (consumed) return;
      } catch (_) {}
    }
    final help = onVolumeUpHelpTab;
    if (help != null) {
      try {
        await help();
      } catch (_) {}
    }
  }

  static void ensureInitialized() {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (_initialized || !isAndroid) return;
    _initialized = true;
    _channel.setMethodCallHandler(_dispatch);
  }
}
