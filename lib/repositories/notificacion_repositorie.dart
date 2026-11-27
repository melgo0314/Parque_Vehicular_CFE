import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/notificacion_model.dart';

// Calcula alertas de mantenimiento a partir del historial y el kilometraje.
class NotificacionRepositorie {
  NotificacionRepositorie({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const int _kilometrosAvisoPreventivo = 10000;

  Future<List<NotificacionModel>> obtenerNotificaciones() async {
    final usuarioActual = _auth.currentUser;
    if (usuarioActual == null) {
      throw StateError(
        'Debes iniciar sesión para consultar las notificaciones.',
      );
    }

    final documentoUsuario =
        await _db.collection('usuario').doc(usuarioActual.uid).get();
    if (!documentoUsuario.exists) {
      throw StateError('No se encontró la información del usuario.');
    }

    final rol = documentoUsuario.data()?['rol']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    if (!{'administrador', 'superusuario', 'operador'}.contains(rol)) {
      throw StateError('No tienes permisos para consultar las notificaciones.');
    }

    final consultaLecturas = await _db
        .collection('notificacion_lectura')
        .where('usuarioUid', isEqualTo: usuarioActual.uid)
        .get();

    final estadosLectura = <String, bool>{};
    for (final documento in consultaLecturas.docs) {
      final datos = documento.data();
      final uid = datos['notificacionUid']?.toString() ?? '';
      if (uid.isNotEmpty) estadosLectura[uid] = datos['leida'] == true;
    }

    final consultaVehiculos = await _db.collection('vehiculo').get();
    final vehiculos = consultaVehiculos.docs.where((documento) {
      final datos = documento.data();
      if ((datos['estado']?.toString().trim().toLowerCase() ?? '') == 'baja') {
        return false;
      }
      return rol != 'operador' ||
          datos['operadorUidActual']?.toString() == usuarioActual.uid;
    });

    final notificaciones = <NotificacionModel>[];

    for (final documentoVehiculo in vehiculos) {
      final datosVehiculo = documentoVehiculo.data();
      final vehiculoUid = documentoVehiculo.id;
      final placas = datosVehiculo['placas']?.toString() ?? '';
      final numeroEconomico =
          (datosVehiculo['numeroEconomico'] ?? datosVehiculo['numeco'])
                  ?.toString() ??
              '';
      final kilometrajeActual = _entero(
        datosVehiculo['kilometrajeActual'] ?? datosVehiculo['kilometraje'],
      );
      // El intervalo se toma del vehículo evaluado, nunca de un valor común.
      final intervalo = _entero(
        datosVehiculo['intervaloPreventivoKm'] ??
            datosVehiculo['intervaloPreventivo'],
        predeterminado: 5000,
      );

      final consultaMantenimientos = await _db
          .collection('mantenimiento')
          .where('vehiculoUid', isEqualTo: vehiculoUid)
          .get();

      final preventivosRealizados = <Map<String, dynamic>>[];
      var existePreventivoProgramadoConFechaOKm = false;

      // Kilometraje del preventivo que quedó regularizado por el correctivo
      // realizado más recientemente.
      final correctivosRegularizados = consultaMantenimientos.docs
          .map((documento) => documento.data())
          .where((datos) {
            final fecha = _fecha(datos['fechaRealizado']);
            final estado = (datos['estado']?.toString() ?? '')
                .trim()
                .toLowerCase();
            return (datos['tipoMantenimiento']?.toString() ?? '')
                    .trim()
                    .toLowerCase() ==
                'correctivo' &&
                datos['regularizaPreventivo'] == true &&
                (estado == 'realizado' || (estado.isEmpty && fecha != null)) &&
                datos['kilometrajeProgramado'] != null &&
                datos['kilometrajeRealizado'] != null;
          })
          .toList();
      correctivosRegularizados.sort((a, b) {
        final fechaA = _fecha(a['fechaRealizado']);
        final fechaB = _fecha(b['fechaRealizado']);
        if (fechaA != null && fechaB != null) return fechaB.compareTo(fechaA);
        return _entero(b['kilometrajeRealizado'])
            .compareTo(_entero(a['kilometrajeRealizado']));
      });
      final int? kilometrajeVencidoRegularizado =
          correctivosRegularizados.isEmpty
              ? null
              : _entero(correctivosRegularizados.first['kilometrajeProgramado']);
      final fechaRegularizacion = correctivosRegularizados.isEmpty
          ? null
          : _fecha(correctivosRegularizados.first['fechaRealizado']);

      for (final documentoMantenimiento in consultaMantenimientos.docs) {
        final datos = documentoMantenimiento.data();
        final mantenimientoUid = documentoMantenimiento.id;
        final tipo = (datos['tipoMantenimiento']?.toString() ?? '')
            .trim()
            .toLowerCase();
        final fechaRealizado = _fecha(datos['fechaRealizado']);
        final estado = (datos['estado']?.toString() ?? '')
                .trim()
                .toLowerCase()
                .isNotEmpty
            ? datos['estado'].toString().trim().toLowerCase()
            : fechaRealizado != null
                ? 'realizado'
                : 'programado';

        if (tipo == 'prueba') continue;

        if (tipo == 'correctivo') {
          if (estado == 'realizado' &&
              datos['regularizaPreventivo'] == true &&
              datos['kilometrajeRealizado'] != null) {
            preventivosRealizados.add({
              ...datos,
              '_uid': mantenimientoUid,
              '_kmRealizado': _entero(datos['kilometrajeRealizado']),
            });
          }

          if (estado != 'realizado') {
            final uidAlerta = '${mantenimientoUid}_correctivo_pendiente';
            notificaciones.add(
              NotificacionModel(
                uid: uidAlerta,
                vehiculoUid: vehiculoUid,
                placas: placas,
                numeroEconomico: numeroEconomico,
                mantenimientoUid: mantenimientoUid,
                tipoAlerta: 'correctivo_pendiente',
                titulo: 'Mantenimiento correctivo pendiente',
                descripcion: 'El vehículo $placas tiene un mantenimiento '
                    'correctivo que todavía no ha sido realizado.',
                fechaProgramada: _fecha(datos['fechaProgramada']),
                kilometrajeProgramado: datos['kilometrajeProgramado'] == null
                    ? null
                    : _entero(datos['kilometrajeProgramado']),
                kilometrajeActual: kilometrajeActual,
                leida: estadosLectura[uidAlerta] ?? false,
              ),
            );
          }
          continue;
        }

        if (tipo != 'preventivo') continue;

        if (estado == 'realizado') {
          final kmRealizado = datos['kilometrajeRealizado'];
          if (kmRealizado != null) {
            preventivosRealizados.add({
              ...datos,
              '_uid': mantenimientoUid,
              '_kmRealizado': _entero(kmRealizado),
            });
          }
          continue;
        }

        final fechaProgramada = _fecha(datos['fechaProgramada']);
        final kmProgramado = datos['kilometrajeProgramado'] == null
            ? null
            : _entero(datos['kilometrajeProgramado']);

        // Un correctivo completado que regulariza este km ya cerró este
        // preventivo programado; no debe mantener activa la alerta vencida.
        if (kmProgramado != null &&
            kilometrajeVencidoRegularizado != null &&
            kmProgramado <= kilometrajeVencidoRegularizado) {
          continue;
        }

        if (fechaProgramada != null &&
            fechaRegularizacion != null &&
            !fechaProgramada.isAfter(fechaRegularizacion)) {
          continue;
        }

        if (fechaProgramada != null || kmProgramado != null) {
          existePreventivoProgramadoConFechaOKm = true;
        }

        _agregarAlertaPreventivaProgramada(
          notificaciones: notificaciones,
          estadosLectura: estadosLectura,
          vehiculoUid: vehiculoUid,
          placas: placas,
          numeroEconomico: numeroEconomico,
          mantenimientoUid: mantenimientoUid,
          fechaProgramada: fechaProgramada,
          kilometrajeProgramado: kmProgramado,
          kilometrajeActual: kilometrajeActual,
        );
      }

      // Si no hay un preventivo pendiente explícito con fecha o kilometraje,
      // calcula el próximo servicio con el último realizado o la base inicial.
      if (!existePreventivoProgramadoConFechaOKm && intervalo > 0) {
        preventivosRealizados.sort(
          (a, b) => (b['_kmRealizado'] as int)
              .compareTo(a['_kmRealizado'] as int),
        );

        final int? kilometrajeBase = preventivosRealizados.isNotEmpty
            ? preventivosRealizados.first['_kmRealizado'] as int
            : datosVehiculo['kilometrajeBasePreventivo'] == null
                ? null
                : _entero(datosVehiculo['kilometrajeBasePreventivo']);

        if (kilometrajeBase != null) {
          final proximoKm = kilometrajeBase + intervalo;
          final kmRestantes = proximoKm - kilometrajeActual;

          if (kmRestantes <= _kilometrosAvisoPreventivo) {
            final vencido = kmRestantes <= 0;
            // El identificador permanece igual cuando la alerta pasa de
            // próxima a vencida, conservando su estado de lectura.
            final uidAlerta = 'auto_${vehiculoUid}_preventivo_$proximoKm';

            notificaciones.add(
              NotificacionModel(
                uid: uidAlerta,
                vehiculoUid: vehiculoUid,
                placas: placas,
                numeroEconomico: numeroEconomico,
                mantenimientoUid: preventivosRealizados.isNotEmpty
                    ? preventivosRealizados.first['_uid'] as String
                    : 'base_preventiva_$vehiculoUid',
                tipoAlerta: vencido
                    ? 'preventivo_vencido'
                    : 'preventivo_proximo',
                titulo: vencido
                    ? 'Mantenimiento preventivo vencido'
                    : 'Próximo mantenimiento preventivo',
                descripcion: vencido
                    ? 'El vehículo $placas superó por '
                        '${kmRestantes.abs()} km el servicio preventivo '
                        'calculado para $proximoKm km.'
                    : 'El vehículo $placas requiere próximamente su '
                        'servicio preventivo. Faltan $kmRestantes km.',
                kilometrajeProgramado: proximoKm,
                kilometrajeActual: kilometrajeActual,
                kilometrosRestantes: kmRestantes,
                leida: estadosLectura[uidAlerta] ?? false,
              ),
            );
          }
        }
      }
    }

    notificaciones.sort((a, b) {
      final prioridad = _prioridad(a.tipoAlerta).compareTo(
        _prioridad(b.tipoAlerta),
      );
      if (prioridad != 0) return prioridad;
      return (a.kilometrosRestantes ?? 0)
          .compareTo(b.kilometrosRestantes ?? 0);
    });

    return notificaciones;
  }

  void _agregarAlertaPreventivaProgramada({
    required List<NotificacionModel> notificaciones,
    required Map<String, bool> estadosLectura,
    required String vehiculoUid,
    required String placas,
    required String numeroEconomico,
    required String mantenimientoUid,
    required DateTime? fechaProgramada,
    required int? kilometrajeProgramado,
    required int kilometrajeActual,
  }) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final diasRestantes = fechaProgramada == null
        ? null
        : DateUtils.dateOnly(fechaProgramada).difference(hoy).inDays;
    final kmRestantes = kilometrajeProgramado == null
        ? null
        : kilometrajeProgramado - kilometrajeActual;

    final vencido = (diasRestantes != null && diasRestantes <= 0) ||
        (kmRestantes != null && kmRestantes <= 0);
    final proximo = (diasRestantes != null &&
            diasRestantes > 0 &&
            diasRestantes <= 7) ||
        (kmRestantes != null &&
            kmRestantes > 0 &&
            kmRestantes <= _kilometrosAvisoPreventivo);

    if (!vencido && !proximo) return;

    final tipoAlerta = vencido ? 'preventivo_vencido' : 'preventivo_proximo';
    final uidAlerta = '${mantenimientoUid}_$tipoAlerta';
    final condiciones = <String>[];

    if (diasRestantes != null) {
      condiciones.add(
        diasRestantes <= 0
            ? 'la fecha programada ya se alcanzó'
            : 'faltan $diasRestantes días',
      );
    }
    if (kmRestantes != null) {
      condiciones.add(
        kmRestantes <= 0
            ? 'se superó el kilometraje programado por ${kmRestantes.abs()} km'
            : 'faltan $kmRestantes km',
      );
    }

    notificaciones.add(
      NotificacionModel(
        uid: uidAlerta,
        vehiculoUid: vehiculoUid,
        placas: placas,
        numeroEconomico: numeroEconomico,
        mantenimientoUid: mantenimientoUid,
        tipoAlerta: tipoAlerta,
        titulo: vencido
            ? 'Mantenimiento preventivo vencido'
            : 'Próximo mantenimiento preventivo',
        descripcion: vencido
            ? 'El mantenimiento preventivo de $placas está vencido: '
                '${condiciones.join(' y ')}.'
            : 'El vehículo $placas requiere próximamente su servicio: '
                '${condiciones.join(' y ')}.',
        fechaProgramada: fechaProgramada,
        kilometrajeProgramado: kilometrajeProgramado,
        kilometrajeActual: kilometrajeActual,
        diasRestantes: diasRestantes,
        kilometrosRestantes: kmRestantes,
        leida: estadosLectura[uidAlerta] ?? false,
      ),
    );
  }

  int _prioridad(String tipo) {
    if (tipo == 'preventivo_vencido') return 1;
    if (tipo == 'preventivo_proximo') return 2;
    if (tipo == 'correctivo_pendiente') return 3;
    return 4;
  }

  int _entero(dynamic valor, {int predeterminado = 0}) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? predeterminado;
  }

  DateTime? _fecha(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    return null;
  }

  DocumentReference<Map<String, dynamic>> _referenciaLectura(
    String usuarioUid,
    String notificacionUid,
  ) {
    return _db
        .collection('notificacion_lectura')
        .doc('${usuarioUid}_$notificacionUid');
  }

  Future<void> marcarComoLeida(String notificacionUid) async {
    final usuarioActual = _auth.currentUser;
    if (usuarioActual == null) throw StateError('Debes iniciar sesión.');

    await _referenciaLectura(usuarioActual.uid, notificacionUid).set({
      'usuarioUid': usuarioActual.uid,
      'notificacionUid': notificacionUid,
      'leida': true,
      'fechaLectura': FieldValue.serverTimestamp(),
    });
  }

  Future<void> marcarTodasComoLeidas(
    List<NotificacionModel> notificaciones,
  ) async {
    final usuarioActual = _auth.currentUser;
    if (usuarioActual == null) throw StateError('Debes iniciar sesión.');

    final pendientes = notificaciones.where((notificacion) {
      return !notificacion.leida;
    }).toList();

    for (var inicio = 0; inicio < pendientes.length; inicio += 500) {
      final lote = _db.batch();
      final fin = (inicio + 500 < pendientes.length)
          ? inicio + 500
          : pendientes.length;

      for (final notificacion in pendientes.sublist(inicio, fin)) {
        lote.set(
          _referenciaLectura(usuarioActual.uid, notificacion.uid),
          {
            'usuarioUid': usuarioActual.uid,
            'notificacionUid': notificacion.uid,
            'leida': true,
            'fechaLectura': FieldValue.serverTimestamp(),
          },
        );
      }

      await lote.commit();
    }
  }
}
