import 'dart:io';

/// Sur Android, localhost du PC = 10.0.2.2 pour l'émulateur.
String getDefaultApiBaseUrl() {
  if (Platform.isAndroid) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}
