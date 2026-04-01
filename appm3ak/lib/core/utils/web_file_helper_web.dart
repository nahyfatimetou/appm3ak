import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Implémentation web - utilise les APIs JavaScript natives
Future<Uint8List> readXFileBytes(XFile file) async {
  try {
    // Essayer readAsBytes d'abord (peut fonctionner dans certains cas)
    return await file.readAsBytes();
  } catch (e) {
    print('⚠️ readAsBytes échoué, utilisation des APIs web natives: $e');
    
    // Utiliser fetch API pour lire le blob URL
    try {
      // Sur le web, le path est généralement un blob URL
      final response = await html.window.fetch(file.path);
      final blob = await response.blob;
      
      // Lire le blob avec FileReader
      final completer = Completer<Uint8List>();
      final reader = html.FileReader();
      
      reader.onLoadEnd.listen((event) {
        if (reader.readyState == html.FileReader.DONE) {
          try {
            final result = reader.result;
            if (result != null) {
              // Le résultat est un ArrayBuffer JavaScript, on peut le convertir directement
              // Utiliser Uint8List.view() pour créer une vue sur l'ArrayBuffer
              final bytes = Uint8List.view(result as dynamic);
              completer.complete(bytes);
            } else {
              completer.completeError(Exception('Impossible de lire le fichier: résultat vide'));
            }
          } catch (e) {
            completer.completeError(e);
          }
        }
      });
      
      reader.onError.listen((event) {
        completer.completeError(Exception('Erreur FileReader: ${reader.error}'));
      });
      
      // Lire le blob
      reader.readAsArrayBuffer(blob);
      
      // Attendre avec timeout
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout lors de la lecture du fichier');
        },
      );
    } catch (e2) {
      print('❌ Erreur lors de la lecture via APIs web: $e2');
      // Si tout échoue, donner un message clair
      throw Exception(
        'Impossible de lire le fichier sur le web. '
        'Veuillez réessayer ou créer un post sans image. '
        'Si le problème persiste, utilisez l\'application mobile.'
      );
    }
  }
}
