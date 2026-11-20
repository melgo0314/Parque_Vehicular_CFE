import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:p_vehicular/models/reporte_model.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';

class ExcelReporteService {
  // Genera el archivo Excel con las cargas de combustible.
  Future<Uint8List> generarCargasCombustible(
    ReporteModel reporte,
  ) async {
    final archivo = Excel.createExcel();

    // 1. Renombrar la hoja por defecto ('Sheet1') para evitar hojas vacías.
    final nombrePorDefecto = archivo.getDefaultSheet();
    if (nombrePorDefecto != null) {
      archivo.rename(nombrePorDefecto, 'Cargas');
    }
    final hoja = archivo['Cargas'];

    // Definición de borde delgado para la tabla
    final bordeTabla = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('0xFF008A45'),
    );

    // Estilos en tonos verdes
    final estiloTitulo = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E4620'), // Verde bosque
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final estiloSubtitulo = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#1B3B1D'),
    );

    final estiloEncabezadoTabla = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#2E7D32'), // Verde esmeralda
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: bordeTabla,
      bottomBorder: bordeTabla,
      leftBorder: bordeTabla,
      rightBorder: bordeTabla,
    );

    final estiloCeldaTexto = CellStyle(
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
      topBorder: bordeTabla,
      bottomBorder: bordeTabla,
      leftBorder: bordeTabla,
      rightBorder: bordeTabla,
    );

    final estiloCeldaCentrada = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: bordeTabla,
      bottomBorder: bordeTabla,
      leftBorder: bordeTabla,
      rightBorder: bordeTabla,
    );

    final estiloCeldaNumero = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      topBorder: bordeTabla,
      bottomBorder: bordeTabla,
      leftBorder: bordeTabla,
      rightBorder: bordeTabla,
    );

    final estiloTotal = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#1E4620'),
      backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'), // Verde menta suave
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      topBorder: bordeTabla,
      bottomBorder: bordeTabla,
      leftBorder: bordeTabla,
      rightBorder: bordeTabla,
    );

    // 2. Insertar filas primero (para evitar desfase de índices con merge)
    // Fila 0: Título
    hoja.appendRow([TextCellValue('REPORTE DE CARGAS DE COMBUSTIBLE')]);
    // Fila 1: Fecha inicial
    hoja.appendRow([
      TextCellValue('Fecha inicial: ${_formatearFecha(reporte.fechaInicio)}'),
    ]);
    // Fila 2: Fecha final
    hoja.appendRow([
      TextCellValue('Fecha final: ${_formatearFecha(reporte.fechaFin)}'),
    ]);
    // Fila 3: Separador vacío
    hoja.appendRow([TextCellValue('')]);

    // Combinar y estilizar el título (Fila 0, columnas A a J)
    hoja.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('J1'),
    );
    for (int col = 0; col < 10; col++) {
      hoja
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .cellStyle = estiloTitulo;
    }
    hoja.setRowHeight(0, 28);

    // Estilizar fechas
    hoja.cell(CellIndex.indexByString('A2')).cellStyle = estiloSubtitulo;
    hoja.cell(CellIndex.indexByString('A3')).cellStyle = estiloSubtitulo;

    // 3. Fila 4: Encabezados de la tabla
    final encabezados = [
      'Fecha de carga',
      'Número económico',
      'Placas',
      'Marca',
      'Modelo',
      'Litros',
      'Tipo de combustible',
      'Kilometraje',
      'Importe (\$)',
      'Observaciones',
    ];

    hoja.appendRow(encabezados.map((e) => TextCellValue(e)).toList());
    hoja.setRowHeight(4, 24);

    for (int col = 0; col < encabezados.length; col++) {
      hoja
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 4))
          .cellStyle = estiloEncabezadoTabla;
    }

    // 4. Filas de registros (a partir de la fila 5)
    int filaActual = 5;
    double sumaLitros = 0;
    double sumaImporte = 0;

    for (final carga in reporte.cargasCombustible) {
      final vehiculo = _buscarVehiculo(
        reporte.vehiculos,
        carga.vehiculoUid,
      );

      sumaLitros += carga.litros;
      sumaImporte += carga.importe;

      hoja.appendRow([
        TextCellValue(_formatearFecha(carga.fechaCarga)),
        TextCellValue(vehiculo?.numeroEconomico ?? 'Sin información'),
        TextCellValue(vehiculo?.placas ?? 'Sin información'),
        TextCellValue(vehiculo?.marca ?? 'Sin información'),
        TextCellValue(vehiculo?.modelo ?? 'Sin información'),
        DoubleCellValue(double.parse(carga.litros.toStringAsFixed(2))),
        TextCellValue(carga.tipoCombustible),
        IntCellValue(carga.kilometraje),
        DoubleCellValue(double.parse(carga.importe.toStringAsFixed(2))),
        TextCellValue(
          carga.observaciones.trim().isEmpty
              ? 'Sin observaciones'
              : carga.observaciones,
        ),
      ]);

      // Aplicar estilos y bordes a cada celda de la fila
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: filaActual)).cellStyle = estiloCeldaCentrada;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: filaActual)).cellStyle = estiloCeldaCentrada;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: filaActual)).cellStyle = estiloCeldaCentrada;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: filaActual)).cellStyle = estiloCeldaTexto;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: filaActual)).cellStyle = estiloCeldaTexto;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: filaActual)).cellStyle = estiloCeldaNumero;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: filaActual)).cellStyle = estiloCeldaCentrada;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: filaActual)).cellStyle = estiloCeldaNumero;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: filaActual)).cellStyle = estiloCeldaNumero;
      hoja.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: filaActual)).cellStyle = estiloCeldaTexto;

      filaActual++;
    }

    // 5. Fila de Totales al final (con bordes en toda la fila de totales)
    hoja.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('TOTALES:'),
      DoubleCellValue(double.parse(sumaLitros.toStringAsFixed(2))),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(double.parse(sumaImporte.toStringAsFixed(2))),
      TextCellValue(''),
    ]);

    for (int col = 4; col <= 8; col++) {
      hoja
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: filaActual))
          .cellStyle = estiloTotal;
    }

    // 6. Ajustar el ancho de las columnas
    final anchosColumnas = [16.0, 20.0, 14.0, 14.0, 20.0, 12.0, 22.0, 15.0, 15.0, 28.0];
    for (int i = 0; i < anchosColumnas.length; i++) {
      hoja.setColumnWidth(i, anchosColumnas[i]);
    }

    final bytes = archivo.save();
    if (bytes == null) {
      throw Exception('No fue posible generar el archivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  VehiculoModel? _buscarVehiculo(
    List<VehiculoModel> vehiculos,
    String vehiculoUid,
  ) {
    for (final vehiculo in vehiculos) {
      if (vehiculo.uid == vehiculoUid) {
        return vehiculo;
      }
    }
    return null;
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }
}
