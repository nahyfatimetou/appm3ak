import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Stub pour mobile - utilise readAsBytes normalement
Future<Uint8List> readXFileBytes(XFile file) async {
  return await file.readAsBytes();
}


