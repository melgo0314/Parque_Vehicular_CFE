import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/notificacion_model.dart';

// Se comunica con Firebase para generar las alertas del parque vehicular.
class NotificacionRepositorie {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtiene las notificaciones según el rol del usuario autenticado.
  Future<List<NotificacionModel>> obtenerNotificaciones() async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión para consultar las notificaciones.');
    }

    // Obtiene el rol del usuario.
    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();

    if (!documentoUsuario.exists) {
      throw StateError('No se encontró la información del usuario.');
    }

    final datosUsuario = documentoUsuario.data() ?? {};
    final rol = datosUsuario['rol']?.toString().toLowerCase() ?? '';

    if (rol != 'administrador' &&
        rol != 'superusuario' &&
        rol != 'operador') {
      throw StateError('No tienes permisos para consultar las notificaciones.');
    }


    // Consulta cuáles notificaciones ya fueron leídas por el usuario.
    final consultaLecturas = await _db
        .collection('notificacion_lectura')
        .where('usuarioUid', isEqualTo: usuarioActual.uid)
        .get();

    final estadosLectura = <String, bool>{};

    for (final documento in consultaLecturas.docs) {
      final datos = documento.data();

      estadosLectura[datos['notificacionUid'].toString()] =
          datos['leida'] == true;
    }


    // Consulta los vehículos registrados.
    final consultaVehiculos = await _db.collection('vehiculo').get();

    final vehiculos = consultaVehiculos.docs.where((documento) {
      final datos = documento.data();

      // El operador solamente consulta su vehículo asignado.
      if (rol == 'operador') {
        return datos['operadorUidActual'] == usuarioActual.uid;
      }

      // El administrador y superusuario consultan todos los vehículos.
      return true;
    }).toList();

    final notificaciones = <NotificacionModel>[];

    // Recorre los vehículos a los que tiene acceso el usuario.
    for (final documentoVehiculo in vehiculos) {
      final datosVehiculo = documentoVehiculo.data();

      final vehiculoUid = documentoVehiculo.id;
      final placas = datosVehiculo['placas']?.toString() ?? '';
      final numeroEconomico =
          (datosVehiculo['numeroEconomico'] ??
                  datosVehiculo['numeco'])
              ?.toString() ??
          '';

      final kilometrajeActual =
          _convertirNumero(datosVehiculo['kilometrajeActual']).toInt();

      // Consulta los mantenimientos del vehículo.
      final consultaMantenimientos = await _db
          .collection('mantenimiento')
          .where('vehiculoUid', isEqualTo: vehiculoUid)
          .get();

      for (final documentoMantenimiento
          in consultaMantenimientos.docs) {
        final datosMantenimiento = documentoMantenimiento.data();

        final mantenimientoUid = documentoMantenimiento.id;

        final tipoMantenimiento =
            datosMantenimiento['tipoMantenimiento']
                ?.toString()
                .toLowerCase() ??
            '';

        final estado =
            datosMantenimiento['estado']?.toString().toLowerCase() ??
            (datosMantenimiento['fechaRealizado'] != null
                ? 'realizado'
                : 'programado');

        // Los mantenimientos realizados no generan alertas.
        if (estado == 'realizado') {
          continue;
        }

        // No se generan alertas para registros de prueba.
        if (tipoMantenimiento == 'prueba') {
          continue;
        }

        // Los mantenimientos correctivos permanecen pendientes
        // hasta que se registren como realizados.
        if (tipoMantenimiento == 'correctivo') {
          notificaciones.add(
            NotificacionModel(
              uid: '${mantenimientoUid}_correctivo_pendiente',
              vehiculoUid: vehiculoUid,
              placas: placas,
              numeroEconomico: numeroEconomico,
              mantenimientoUid: mantenimientoUid,
              tipoAlerta: 'correctivo_pendiente',
              titulo: 'Mantenimiento correctivo pendiente',
              descripcion:
                  'El vehículo $placas tiene un mantenimiento '
                  'correctivo que todavía no ha sido realizado.',
              fechaProgramada: _convertirFecha(
                datosMantenimiento['fechaProgramada'],
              ),
              kilometrajeProgramado:
                  datosMantenimiento['kilometrajeProgramado'] == null
                      ? null
                      : _convertirNumero(
                          datosMantenimiento['kilometrajeProgramado'],
                        ).toInt(),
              kilometrajeActual: kilometrajeActual,
              leida: estadosLectura[
                '${mantenimientoUid}_correctivo_pendiente'
                ] ?? false,
            ),
          );

          continue;
        }

        // Solamente se evalúan los mantenimientos preventivos.
        if (tipoMantenimiento != 'preventivo') {
          continue;
        }

        final fechaProgramada = _convertirFecha(
          datosMantenimiento['fechaProgramada'],
        );

        final kilometrajeProgramado =
            datosMantenimiento['kilometrajeProgramado'] == null
                ? null
                : _convertirNumero(
                    datosMantenimiento['kilometrajeProgramado'],
                  ).toInt();

        final hoy = DateUtils.dateOnly(DateTime.now());

        int? diasRestantes;

        if (fechaProgramada != null) {
          final fecha = DateUtils.dateOnly(fechaProgramada);
          diasRestantes = fecha.difference(hoy).inDays;
        }

        int? kilometrosRestantes;

        if (kilometrajeProgramado != null) {
          kilometrosRestantes =
              kilometrajeProgramado - kilometrajeActual;
        }

        // Comprueba si se alcanzó alguna de las condiciones de vencimiento.
        final vencidoPorFecha =
            diasRestantes != null && diasRestantes <= 0;

        final vencidoPorKilometraje =
            kilometrosRestantes != null && kilometrosRestantes <= 0;

        // Comprueba si falta una semana o 500 km para el mantenimiento.
        final proximoPorFecha =
            diasRestantes != null &&
            diasRestantes > 0 &&
            diasRestantes <= 7;

        final proximoPorKilometraje =
            kilometrosRestantes != null &&
            kilometrosRestantes > 0 &&
            kilometrosRestantes <= 500;

        // Si ya venció por alguna condición, tiene prioridad.
        if (vencidoPorFecha || vencidoPorKilometraje) {
          String descripcion = 'El mantenimiento preventivo del vehículo '
              '$placas está vencido.';

          if (vencidoPorFecha && vencidoPorKilometraje) {
            descripcion +=
                ' Se alcanzó la fecha y el kilometraje programados.';
          } else if (vencidoPorFecha) {
            descripcion += ' Ya se alcanzó la fecha programada.';
          } else {
            descripcion += ' Ya se alcanzó el kilometraje programado.';
          }

          notificaciones.add(
            NotificacionModel(
              uid: '${mantenimientoUid}_preventivo_vencido',
              vehiculoUid: vehiculoUid,
              placas: placas,
              numeroEconomico: numeroEconomico,
              mantenimientoUid: mantenimientoUid,
              tipoAlerta: 'preventivo_vencido',
              titulo: 'Mantenimiento preventivo vencido',
              descripcion: descripcion,
              fechaProgramada: fechaProgramada,
              kilometrajeProgramado: kilometrajeProgramado,
              kilometrajeActual: kilometrajeActual,
              leida: estadosLectura[
                '${mantenimientoUid}_preventivo_vencido'
                ] ?? false,
              diasRestantes: diasRestantes,
              kilometrosRestantes: kilometrosRestantes,
            ),
          );
        } else if (proximoPorFecha || proximoPorKilometraje) {
          String descripcion = 'El vehículo $placas requiere próximamente '
              'un mantenimiento preventivo.';

          if (proximoPorFecha && proximoPorKilometraje) {
            descripcion +=
                ' Faltan $diasRestantes días y '
                '$kilometrosRestantes km.';
          } else if (proximoPorFecha) {
            descripcion += ' Faltan $diasRestantes días.';
          } else {
            descripcion += ' Faltan $kilometrosRestantes km.';
          }

          notificaciones.add(
            NotificacionModel(
              uid: '${mantenimientoUid}_preventivo_proximo',
              vehiculoUid: vehiculoUid,
              placas: placas,
              numeroEconomico: numeroEconomico,
              mantenimientoUid: mantenimientoUid,
              tipoAlerta: 'preventivo_proximo',
              titulo: 'Próximo mantenimiento preventivo',
              descripcion: descripcion,
              fechaProgramada: fechaProgramada,
              kilometrajeProgramado: kilometrajeProgramado,
              kilometrajeActual: kilometrajeActual,
              leida: estadosLectura[
                '${mantenimientoUid}_preventivo_proximo'
                ] ?? false,
              diasRestantes: diasRestantes,
              kilometrosRestantes: kilometrosRestantes,
            ),
          );
        }
      }
    }

    // Ordena primero las alertas vencidas, después las próximas
    // y finalmente los mantenimientos correctivos pendientes.
    notificaciones.sort((a, b) {
      return _obtenerPrioridad(a.tipoAlerta)
          .compareTo(_obtenerPrioridad(b.tipoAlerta));
    });

    return notificaciones;
  }

  // Asigna prioridad a cada tipo de notificación.
  int _obtenerPrioridad(String tipo) {
    if (tipo == 'preventivo_vencido') return 1;
    if (tipo == 'preventivo_proximo') return 2;
    if (tipo == 'correctivo_pendiente') return 3;

    return 4;
  }

  // Convierte valores numéricos de Firebase.
  double _convertirNumero(dynamic valor) {
    if (valor is num) {
      return valor.toDouble();
    }

    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }

  // Convierte una fecha de Firebase a DateTime.
  DateTime? _convertirFecha(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    return null;
  }

  // Genera la referencia del estado de lectura de una notificación.
  DocumentReference<Map<String, dynamic>> _referenciaLectura(
    String usuarioUid,
    String notificacionUid,
  ) {
    return _db
        .collection('notificacion_lectura')
        .doc('${usuarioUid}_$notificacionUid');
  }

  // Marca una notificación como leída.
  Future<void> marcarComoLeida(
    String notificacionUid,
  ) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión.');
    }

    await _referenciaLectura(
      usuarioActual.uid,
      notificacionUid,
    ).set({
      'usuarioUid': usuarioActual.uid,
      'notificacionUid': notificacionUid,
      'leida': true,
      'fechaLectura': FieldValue.serverTimestamp(),
    });
  }

  // Marca todas las notificaciones como leídas.
  Future<void> marcarTodasComoLeidas(
    List<NotificacionModel> notificaciones,
  ) async {
    final usuarioActual = _auth.currentUser;

    if (usuarioActual == null) {
      throw StateError('Debes iniciar sesión.');
    }

    final pendientes = notificaciones.where((notificacion) {
      return !notificacion.leida;
    }).toList();

    // Firestore permite hasta 500 operaciones por lote.
    for (var i = 0; i < pendientes.length; i += 500) {
      final lote = _db.batch();

      final fin = (i + 500 < pendientes.length)
          ? i + 500
          : pendientes.length;

      for (final notificacion in pendientes.sublist(i, fin)) {
        final referencia = _referenciaLectura(
          usuarioActual.uid,
          notificacion.uid,
        );

        lote.set(referencia, {
          'usuarioUid': usuarioActual.uid,
          'notificacionUid': notificacion.uid,
          'leida': true,
          'fechaLectura': FieldValue.serverTimestamp(),
        });
      }

      await lote.commit();
    }
  }

}
