
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class GuardarReporteService {
  // Guarda un documento PDF y abre el selector de ubicación.
  Future<String?> guardarPDF({
    required String nombre,
    required List<int> bytes,
  }) async {
    return await FileSaver.instance.saveAs(
      name: nombre,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'pdf', 
      mimeType: MimeType.pdf,
      dialogTitle: 'Guardar reporte PDF',
    );
  }

  // Guarda un documento Excel y abre el selector de ubicación.
  Future<String?> guardarExcel({
    required String nombre,
    required List<int> bytes,
  }) async {
    return await FileSaver.instance.saveAs(
      name: nombre,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
      dialogTitle: 'Guardar reporte Excel',
    );
  }
}
