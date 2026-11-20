import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:p_vehicular/models/reporte_model.dart';
import 'package:p_vehicular/models/vehiculos_model.dart';
import 'package:p_vehicular/models/combustible_model.dart';

class PdfReporteService {
  
  // Genera el PDF de kilometraje con gráfica.
  Future<Uint8List> generarKilometraje(ReporteModel reporte) async {
    final contenido = <pw.Widget>[];

    for (final vehiculo in reporte.vehiculos) {
      final registros = reporte.registrosKilometraje
          .where((registro) => registro.vehiculoUid == vehiculo.uid)
          .toList();

      registros.sort((a, b) => a.fecha.compareTo(b.fecha));

      contenido.add(_tituloSeccion(_nombreVehiculo(vehiculo)));

      // Primero se muestra la tabla.
      contenido.add(
        _crearTabla(
          encabezados: [
            'Fecha',
            'Inicial',
            'Final',
            'Recorrido',
            'Observaciones',
          ],
          filas: registros.map((registro) {
            return [
              _fecha(registro.fecha),
              '${registro.kilometrajeIni} km',
              '${registro.kilometrajeFinal} km',
              '${registro.kilometrajeFinal! - registro.kilometrajeIni} km',
              _texto(registro.observaciones),
            ];
          }).toList(),
        ),
      );

      contenido.add(pw.SizedBox(height: 20));

      // Después de la tabla se muestra la gráfica.
      contenido.add(
        _crearGrafica(
          titulo: 'Kilometraje final por registro',
          valores: registros.map((registro) {
            return _ValorGrafica(
              etiqueta: _fecha(registro.fecha),
              valor: registro.kilometrajeFinal!.toDouble(),
            );
          }).toList(),
          sufijo: ' km',
        ),
      );

      contenido.add(pw.SizedBox(height: 18));
    }

    return _crearDocumento(
      titulo: 'Reporte de kilometraje',
      reporte: reporte,
      contenido: contenido,
    );
  }


  // Genera el PDF de rendimiento de combustible con gráficas.
  Future<Uint8List> generarRendimiento(ReporteModel reporte) async {
    final contenido = <pw.Widget>[];

    for (final vehiculo in reporte.vehiculos) {
      final cargas = _obtenerCargasVehiculo(reporte, vehiculo.uid);

      final rendimientos = _calcularRendimientos(cargas);

      final totalLitros = reporte.cargasCombustible
          .where((carga) => carga.vehiculoUid == vehiculo.uid)
          .fold<double>(0, (total, carga) => total + carga.litros);

      final totalImporte = reporte.cargasCombustible
          .where((carga) => carga.vehiculoUid == vehiculo.uid)
          .fold<double>(0, (total, carga) => total + carga.importe);

      final rendimientoPromedio = rendimientos.isEmpty
          ? 0.0
          : rendimientos.fold<double>(
                0,
                (total, rendimiento) => total + rendimiento.valor,
              ) /
              rendimientos.length;

      contenido.add(_tituloSeccion(_nombreVehiculo(vehiculo)));

      contenido.add(
        pw.Text('Resumen de consumo'),
      );

      contenido.add(
        pw.SizedBox(height: 7),
      );

      contenido.add(
        pw.Text('Litros consumidos: ${_decimal(totalLitros)} L'),
      );

      contenido.add(
        pw.Text('Importe total: \$${_decimal(totalImporte)}'),
      );

      contenido.add(
        pw.Text(
          'Rendimiento promedio: ${_decimal(rendimientoPromedio)} km/L',
        ),
      );

      contenido.add(pw.SizedBox(height: 14));

      // Primero se muestra la tabla de cargas de combustible.
      contenido.add(
        _crearTabla(
          encabezados: [
            'Fecha',
            'Litros',
            'Kilometraje',
            'Importe',
            'Rendimiento',
          ],
          filas: reporte.cargasCombustible
              .where((carga) => carga.vehiculoUid == vehiculo.uid)
              .map((carga) {
            final rendimiento = rendimientos
                .where((elemento) => elemento.uid == carga.uid)
                .toList();

            return [
              _fecha(carga.fechaCarga),
              '${_decimal(carga.litros)} L',
              '${carga.kilometraje} km',
              '\$${_decimal(carga.importe)}',
              rendimiento.isEmpty
                  ? 'No calculable'
                  : '${_decimal(rendimiento.first.valor)} km/L',
            ];
          }).toList(),
        ),
      );

      contenido.add(pw.SizedBox(height: 20));

      // Gráfica de rendimiento debajo de la tabla.
      contenido.add(
        _crearGrafica(
          titulo: 'Rendimiento por carga',
          valores: rendimientos.map((rendimiento) {
            return _ValorGrafica(
              etiqueta: rendimiento.etiqueta,
              valor: rendimiento.valor,
            );
          }).toList(),
          sufijo: ' km/L',
        ),
      );

      contenido.add(pw.SizedBox(height: 20));

      // Gráfica de litros debajo de la primera gráfica.
      contenido.add(
        _crearGrafica(
          titulo: 'Litros por carga',
          valores: reporte.cargasCombustible
              .where((carga) => carga.vehiculoUid == vehiculo.uid)
              .map((carga) {
            return _ValorGrafica(
              etiqueta: _fecha(carga.fechaCarga),
              valor: carga.litros,
            );
          }).toList(),
          sufijo: ' L',
        ),
      );

      contenido.add(pw.SizedBox(height: 20));
    }

    return _crearDocumento(
      titulo: 'Reporte de rendimiento de combustible',
      reporte: reporte,
      contenido: contenido,
    );
  }

  // Genera el PDF de mantenimientos 
  Future<Uint8List> generarMantenimientos(ReporteModel reporte) async {
    final contenido = <pw.Widget>[];

    for (final vehiculo in reporte.vehiculos) {
      final mantenimientos = reporte.mantenimientos
          .where((mantenimiento) {
        return mantenimiento.vehiculoUid == vehiculo.uid &&
            mantenimiento.tipoMantenimiento.toLowerCase() != 'correctivo';
      }).toList();

      contenido.add(_tituloSeccion(_nombreVehiculo(vehiculo)));

      contenido.add(
        _crearTabla(
          encabezados: [
            'Fecha',
            'Tipo',
            'Módulo',
            'Trabajo realizado',
            'Proveedor',
            'Costo',
            'Observaciones',
          ],
          filas: mantenimientos.map((mantenimiento) {
            return [
              _fecha(mantenimiento.fechaRealizado),
              _texto(mantenimiento.tipoMantenimiento),
              _texto(mantenimiento.modulo),
              _texto(mantenimiento.trabajoRealizado),
              _texto(mantenimiento.proveedor),
              '\$${_decimal(mantenimiento.costo)}',
              _texto(mantenimiento.observaciones),
            ];
          }).toList(),
        ),
      );

      contenido.add(pw.SizedBox(height: 20));
    }

    return _crearDocumento(
      titulo: 'Reporte de mantenimientos',
      reporte: reporte,
      contenido: contenido,
    );
  }

  // Genera el PDF de reparaciones 
  Future<Uint8List> generarReparaciones(ReporteModel reporte) async {
    final contenido = <pw.Widget>[];

    for (final vehiculo in reporte.vehiculos) {
      final reparaciones = reporte.mantenimientos
          .where((mantenimiento) {
        return mantenimiento.vehiculoUid == vehiculo.uid &&
            mantenimiento.tipoMantenimiento.toLowerCase() == 'correctivo';
      }).toList();

      contenido.add(_tituloSeccion(_nombreVehiculo(vehiculo)));

      for (final reparacion in reparaciones) {
        contenido.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Fecha: ${_fecha(reparacion.fechaRealizado)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text('Módulo: ${_texto(reparacion.modulo)}'),
                pw.Text(
                  'Trabajo realizado: ${_texto(reparacion.trabajoRealizado)}',
                ),
                pw.Text(
                  'Observaciones: ${_texto(reparacion.observaciones)}',
                ),
                pw.Text('Proveedor: ${_texto(reparacion.proveedor)}'),
                pw.Text('Costo: \$${_decimal(reparacion.costo)}'),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Refacciones utilizadas:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (reparacion.detalleRefacciones.isEmpty)
                  pw.Text('No se registraron refacciones.')
                else
                  ...reparacion.detalleRefacciones.map((refaccion) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(
                        left: 8,
                        top: 3,
                      ),
                      child: pw.Text(
                        '${refaccion.nombre} - Cantidad: ${refaccion.cantidad}',
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      }

      contenido.add(pw.SizedBox(height: 12));
    }

    return _crearDocumento(
      titulo: 'Reporte de reparaciones',
      reporte: reporte,
      contenido: contenido,
    );
  }

  // Construye el documento PDF con encabezado y pie de página.
  Future<Uint8List> _crearDocumento({
    required String titulo,
    required ReporteModel reporte,
    required List<pw.Widget> contenido,
  }) async {
    final documento = pw.Document();

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.green800,
                  width: 2,
                ),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CFE - Gestión del Parque Vehicular',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.Text('Reporte administrativo'),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              titulo,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Periodo: ${_fecha(reporte.fechaInicio)} al ${_fecha(reporte.fechaFin)}',
            ),
            pw.SizedBox(height: 18),
            ...contenido,
          ];
        },
      ),
    );

    return documento.save();
  }


  // Construye la gráfica
pw.Widget _crearGrafica({
  required String titulo,
  required List<_ValorGrafica> valores,
  String sufijo = '',
}) {
  if (valores.isEmpty) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      child: pw.Text('No hay datos para mostrar en la gráfica.'),
    );
  }

  double maximo = 0;
  for (var elemento in valores) {
    if (elemento.valor > maximo) {
      maximo = elemento.valor;
    }
  }
  if (maximo <= 0) {
    maximo = 1;
  }

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(15),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            titulo,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Eje Y: Valor ($sufijo)',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 8),

        // Área de la gráfica (Ejes + Barras + Etiquetas abajo)
        pw.Column(
          children: [
            // 1. FILA SUPERIOR: Valores Y + Ejes + Barras
            pw.Container(
              height: 175,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Valores del eje Y
                  pw.Container(
                    width: 45,
                    height: 175,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(maximo.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7)),
                        pw.Text((maximo * 0.75).toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7)),
                        pw.Text((maximo * 0.50).toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7)),
                        pw.Text((maximo * 0.25).toStringAsFixed(0), style: const pw.TextStyle(fontSize: 7)),
                        pw.Text('0', style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Contenedor con los bordes de los ejes y las barras
                  pw.Expanded(
                    child: pw.Container(
                      height: 175,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          left: pw.BorderSide(color: PdfColors.grey700),
                          bottom: pw.BorderSide(color: PdfColors.grey700),
                        ),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: valores.map((elemento) {
                          // Ajusté la altura máxima a 155 para aprovechar mejor el espacio
                          double altura = (elemento.valor / maximo) * 155;
                          if (altura < 2) {
                            altura = 2;
                          }
                          return pw.Expanded(
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Text(
                                  elemento.valor.toStringAsFixed(1),
                                  style: const pw.TextStyle(fontSize: 6),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Container(
                                  width: 14,
                                  height: altura,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.green700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 4),
            pw.Row(
              children: [
                // Espacio equivalente al ancho de los textos del eje Y (45 + 8)
                pw.SizedBox(width: 53),
                pw.Expanded(
                  child: pw.Row(
                    children: valores.map((elemento) {
                      return pw.Expanded(
                        child: pw.Center(
                          child: pw.Text(
                            elemento.etiqueta,
                            maxLines: 1,
                            style: const pw.TextStyle(fontSize: 6),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'Eje X: Fecha del registro',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );
}


  // Construye una tabla con encabezados y registros.
  pw.Widget _crearTabla({
    required List<String> encabezados,
    required List<List<String>> filas,
  }) {
    if (filas.isEmpty) {
      return pw.Text('No hay registros disponibles para este periodo.');
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      columnWidths: {
        for (int i = 0; i < encabezados.length; i++)
          i: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.green800,
          ),
          children: encabezados.map((encabezado) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                encabezado,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
        ...filas.map((fila) {
          return pw.TableRow(
            children: fila.map((dato) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  dato,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  // Construye un título para cada vehículo.
  pw.Widget _tituloSeccion(String titulo) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      color: PdfColors.green100,
      child: pw.Text(
        titulo,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green900,
        ),
      ),
    );
  }

  // Obtiene las cargas del vehículo e incorpora la carga anterior al periodo.
  List<CombustibleModel> _obtenerCargasVehiculo(
    ReporteModel reporte,
    String vehiculoUid,
  ) {
    final cargas = reporte.cargasCombustible
        .where((carga) => carga.vehiculoUid == vehiculoUid)
        .toList();

    cargas.addAll(
      reporte.cargasCombustibleAnteriores.where(
        (carga) => carga.vehiculoUid == vehiculoUid,
      ),
    );

    cargas.sort(
      (a, b) => a.fechaCarga.compareTo(b.fechaCarga),
    );

    return cargas;
  }

  // Calcula el rendimiento entre cargas consecutivas.
  List<_ValorRendimiento> _calcularRendimientos(
    List<CombustibleModel> cargas,
  ) {
    final rendimientos = <_ValorRendimiento>[];

    for (int i = 1; i < cargas.length; i++) {
      final anterior = cargas[i - 1];
      final actual = cargas[i];

      final diferencia = actual.kilometraje - anterior.kilometraje;

      if (diferencia <= 0 || actual.litros <= 0) {
        continue;
      }

      final rendimiento = diferencia / actual.litros;

      rendimientos.add(
        _ValorRendimiento(
          uid: actual.uid,
          etiqueta: _fecha(actual.fechaCarga),
          valor: rendimiento,
        ),
      );
    }

    return rendimientos;
  }

  // Obtiene el nombre identificador del vehículo.
  String _nombreVehiculo(VehiculoModel vehiculo) {
    return 'Vehículo ${vehiculo.numeroEconomico} - '
        '${vehiculo.marca} ${vehiculo.modelo}';
  }

  // Convierte una fecha a formato día/mes/año.
  String _fecha(DateTime? fecha) {
    if (fecha == null) {
      return 'Sin información';
    }

    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  // Convierte un valor decimal a texto.
  String _decimal(double valor) {
    return valor.toStringAsFixed(2);
  }

  // Evita mostrar valores nulos o vacíos.
  String _texto(String valor) {
    return valor.trim().isEmpty ? 'Sin información' : valor.trim();
  }
}

// Almacena los datos que se mostrarán en una gráfica.
class _ValorGrafica {
  final String etiqueta;
  final double valor;

  const _ValorGrafica({
    required this.etiqueta,
    required this.valor,
  });
}

// Almacena los resultados del cálculo de rendimiento.
class _ValorRendimiento {
  final String uid;
  final String etiqueta;
  final double valor;

  const _ValorRendimiento({
    required this.uid,
    required this.etiqueta,
    required this.valor,
  });
}
