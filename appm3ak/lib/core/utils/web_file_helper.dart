import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

// Import conditionnel pour le web
import 'web_file_helper_stub.dart'
    if (dart.library.html) 'web_file_helper_web.dart' as web_helper;

/// Helper pour lire les bytes d'un XFile de manière compatible avec toutes les plateformes.
/// Sur le web, utilise les APIs JavaScript natives via dart:html.
Future<Uint8List> readXFileBytes(XFile file) async {
  if (kIsWeb) {
    // Sur le web, utiliser l'implémentation web-specific
    return await web_helper.readXFileBytes(file);
  } else {
    // Sur mobile, utiliser readAsBytes normalement
    return await file.readAsBytes();
  }
}

