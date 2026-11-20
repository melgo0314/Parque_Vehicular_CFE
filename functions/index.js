const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { GoogleAuth } = require('google-auth-library');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const nodemailer = require('nodemailer');
const BREVO_SMTP_LOGIN = defineSecret('BREVO_SMTP_LOGIN');
const BREVO_SMTP_KEY = defineSecret('BREVO_SMTP_KEY');
const BREVO_FROM_EMAIL = defineSecret('BREVO_FROM_EMAIL');


initializeApp();

const db = getFirestore();
const auth = getAuth();

const ROLES_PERMITIDOS = new Set([
  'administrador',
  'superusuario',
]);

function texto(valor) {
  return typeof valor === 'string' ? valor.trim() : '';
}

async function verificarAdministrador(uid) {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  }

  const documento = await db.collection('usuario').doc(uid).get();
  const rol = texto(documento.data()?.rol).toLowerCase();

  if (!documento.exists || !ROLES_PERMITIDOS.has(rol)) {
    throw new HttpsError(
      'permission-denied',
      'Solo un administrador puede realizar esta operación.',
    );
  }
}

function convertirErrorAuth(error) {
  if (error instanceof HttpsError) return error;

  switch (error.code) {
    case 'auth/email-already-exists':
      return new HttpsError(
        'already-exists',
        'Ese correo ya está registrado en Firebase Authentication.',
      );
    case 'auth/user-not-found':
      return new HttpsError(
        'not-found',
        'No existe una cuenta de Authentication con ese UID.',
      );
    case 'auth/invalid-email':
      return new HttpsError('invalid-argument', 'El correo no es válido.');
    case 'auth/invalid-password':
      return new HttpsError(
        'invalid-argument',
        'La contraseña debe tener al menos 8 caracteres.',
      );
    default:
      console.error('Error de Firebase Authentication:', error);
      return new HttpsError(
        'internal',
        'Firebase no pudo completar la operación de Authentication.',
      );
  }
}

exports.actualizarUsuario = onCall(async (request) => {
  await verificarAdministrador(request.auth?.uid);

  const uid = texto(request.data?.uid);
  const perfil = request.data?.perfil;
  const nuevaContrasena = texto(request.data?.nuevaContrasena);

  if (!uid || !perfil || typeof perfil !== 'object') {
    throw new HttpsError(
      'invalid-argument',
      'Faltan los datos del usuario que se desea actualizar.',
    );
  }

  const nombre = texto(perfil.nombre);
  const apellidoP = texto(perfil.apellidoP);
  const apellidoM = texto(perfil.apellidoM);
  const correo = texto(perfil.correo).toLowerCase();
  const rol = texto(perfil.rol).toLowerCase();
  const rpe = texto(perfil.rpe);
  const telefono = texto(perfil.telefono);
  const urlLicencia = texto(perfil.urlLicencia);

  if (!nombre || !correo || !rol) {
    throw new HttpsError(
      'invalid-argument',
      'Nombre, correo y rol son obligatorios.',
    );
  }

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo)) {
    throw new HttpsError('invalid-argument', 'El correo no tiene formato válido.');
  }

  if (!['administrador', 'operador', 'superusuario'].includes(rol)) {
    throw new HttpsError('invalid-argument', 'El rol seleccionado no es válido.');
  }

  if (nuevaContrasena && nuevaContrasena.length < 8) {
    throw new HttpsError(
      'invalid-argument',
      'La contraseña debe tener al menos 8 caracteres.',
    );
  }

  const referencia = db.collection('usuario').doc(uid);
  const documentoAnterior = await referencia.get();

  if (!documentoAnterior.exists) {
    throw new HttpsError('not-found', 'No se encontró el perfil en Firestore.');
  }

  let cuentaAnterior;

  try {
    cuentaAnterior = await auth.getUser(uid);
  } catch (error) {
    throw convertirErrorAuth(error);
  }

  const datosAnteriores = documentoAnterior.data();
  const nuevoPerfil = {
    nombre,
    apellidoP,
    apellidoM,
    correo,
    rol,
    rpe,
    telefono,
    urlLicencia,
    actualizadoEn: FieldValue.serverTimestamp(),
  };

  const cambiosAuth = {
    email: correo,
    displayName: `${nombre} ${apellidoP} ${apellidoM}`.trim(),
  };

  if (correo !== cuentaAnterior.email) {
    cambiosAuth.emailVerified = false;
  }

  if (nuevaContrasena) {
    cambiosAuth.password = nuevaContrasena;
  }

  try {
    // Primero se actualiza el perfil. Si Auth falla, se restaura el documento.
    await referencia.update(nuevoPerfil);
    await auth.updateUser(uid, cambiosAuth);

    return { correcto: true };
  } catch (error) {
    try {
      await referencia.set(datosAnteriores);
    } catch (errorRestauracion) {
      console.error('No se pudo restaurar el perfil anterior:', errorRestauracion);
    }

    throw convertirErrorAuth(error);
  }
});

exports.eliminarUsuario = onCall(async (request) => {
  const uidSolicitante = request.auth?.uid;
  await verificarAdministrador(uidSolicitante);

  const uid = texto(request.data?.uid);

  if (!uid) {
    throw new HttpsError(
      'invalid-argument',
      'No se recibió el UID del usuario que se desea eliminar.',
    );
  }

  if (uid === uidSolicitante) {
    throw new HttpsError(
      'failed-precondition',
      'No puedes eliminar tu propia cuenta desde esta pantalla.',
    );
  }

  const referencia = db.collection('usuario').doc(uid);
  const documento = await referencia.get();

  let cuentaExiste = true;

  try {
    await auth.getUser(uid);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      cuentaExiste = false;
    } else {
      throw convertirErrorAuth(error);
    }
  }

  if (!documento.exists && !cuentaExiste) {
    throw new HttpsError(
      'not-found',
      'No existe el perfil ni la cuenta de Authentication para ese UID.',
    );
  }

  const datosAnteriores = documento.exists ? documento.data() : null;

  try {
    if (documento.exists) {
      await referencia.delete();
    }

    if (cuentaExiste) {
      await auth.deleteUser(uid);
    }

    try {
      await getStorage()
        .bucket()
        .file(`licencias/${uid}.jpg`)
        .delete({ ignoreNotFound: true });
    } catch (errorStorage) {
      // La cuenta y el perfil ya se eliminaron
      console.error('No se pudo borrar la foto de licencia:', errorStorage);
    }

    return { correcto: true };
  } catch (error) {
    // Si falla la eliminación de Authentication, intenta restaurar el perfil.
    if (datosAnteriores) {
      try {
        await referencia.set(datosAnteriores);
      } catch (errorRestauracion) {
        console.error('No se pudo restaurar el perfil:', errorRestauracion);
      }
    }

    throw convertirErrorAuth(error);
  }

});


// ============================================
// ENVÍO AUTOMÁTICO DE NOTIFICACIONES POR CORREO
// ============================================

// Zona horaria de México.
const ZONA_HORARIA = 'America/Mexico_City';

// Obtiene un número válido.
function convertirNumero(valor) {
  if (typeof valor === 'number') return valor;

  return Number(valor) || 0;
}

// Convierte una fecha de Firestore.
function convertirFecha(valor) {
  if (!valor) return null;

  if (valor.toDate) return valor.toDate();

  if (valor instanceof Date) return valor;

  return null;
}

// Obtiene la fecha en formato YYYY-MM-DD en horario de México.
function fechaLocal(fecha) {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA_HORARIA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(fecha);

  const valores = {};

  partes.forEach(parte => {
    valores[parte.type] = parte.value;
  });

  return `${valores.year}-${valores.month}-${valores.day}`;
}

// Calcula los días restantes entre dos fechas.
function calcularDiasRestantes(fecha) {
  const hoy = fechaLocal(new Date());
  const programada = fechaLocal(fecha);

  const [anioH, mesH, diaH] = hoy.split('-').map(Number);
  const [anioP, mesP, diaP] = programada.split('-').map(Number);

  const fechaHoy = Date.UTC(anioH, mesH - 1, diaH);
  const fechaProgramada = Date.UTC(anioP, mesP - 1, diaP);

  return Math.round(
    (fechaProgramada - fechaHoy) / 86400000
  );
}

// Formatea una fecha para el correo.
function formatearFecha(fecha) {
  if (!fecha) return 'No especificada';

  return new Intl.DateTimeFormat('es-MX', {
    day: '2-digit',
    month: 'long',
    year: 'numeric',
    timeZone: ZONA_HORARIA,
  }).format(fecha);
}

// Evita insertar etiquetas HTML desde los datos.
function escaparHTML(valor) {
  return String(valor ?? '').replace(/[&<>"']/g, caracter => {
    const caracteres = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };

    return caracteres[caracter];
  });
}

// Genera las notificaciones de todos los vehículos.
async function obtenerAlertasActivas() {
  const consultaVehiculos = await db.collection('vehiculo').get();

  const alertas = [];

  for (const documentoVehiculo of consultaVehiculos.docs) {
    const datosVehiculo = documentoVehiculo.data();

    const vehiculoUid = documentoVehiculo.id;

    const operadorUid = datosVehiculo.operadorUidActual;

    // Sin operador asignado no se envía ningún correo.
    if (!operadorUid) continue;

    const placas = datosVehiculo.placas?.toString() ?? '';

    const numeroEconomico = (
      datosVehiculo.numeroEconomico ??
      datosVehiculo.numeco ??
      ''
    ).toString();

    const kilometrajeActual = convertirNumero(
      datosVehiculo.kilometrajeActual
    );

    const consultaMantenimientos = await db
      .collection('mantenimiento')
      .where('vehiculoUid', '==', vehiculoUid)
      .get();

    for (const documentoMantenimiento of consultaMantenimientos.docs) {
      const datos = documentoMantenimiento.data();

      const mantenimientoUid = documentoMantenimiento.id;

      const tipo = datos.tipoMantenimiento?.toString().toLowerCase() ?? '';

      const estado = datos.estado?.toString().toLowerCase() ??
        (datos.fechaRealizado ? 'realizado' : 'programado');

      if (estado === 'realizado') continue;

      if (tipo === 'prueba') continue;

      // MANTENIMIENTO CORRECTIVO PENDIENTE.
      if (tipo === 'correctivo') {
        alertas.push({
          vehiculoUid,
          operadorUid,
          placas,
          numeroEconomico,
          mantenimientoUid,
          tipoAlerta: 'correctivo_pendiente',
          titulo: 'Mantenimiento correctivo pendiente',
          descripcion:
            `El vehículo ${placas} tiene un mantenimiento ` +
            'correctivo que todavía no ha sido realizado.',
          fechaProgramada: convertirFecha(datos.fechaProgramada),
          kilometrajeProgramado:
            datos.kilometrajeProgramado == null
              ? null
              : convertirNumero(datos.kilometrajeProgramado),
          kilometrajeActual,
        });

        continue;
      }

      if (tipo !== 'preventivo') continue;

      // DATOS DEL MANTENIMIENTO PREVENTIVO.
      const fechaProgramada = convertirFecha(
        datos.fechaProgramada
      );

      const kilometrajeProgramado =
        datos.kilometrajeProgramado == null
          ? null
          : convertirNumero(datos.kilometrajeProgramado);

      let diasRestantes = null;

      if (fechaProgramada) {
        diasRestantes = calcularDiasRestantes(fechaProgramada);
      }

      let kilometrosRestantes = null;

      if (kilometrajeProgramado !== null) {
        kilometrosRestantes =
          kilometrajeProgramado - kilometrajeActual;
      }

      const vencidoPorFecha =
        diasRestantes !== null && diasRestantes <= 0;

      const vencidoPorKilometraje =
        kilometrosRestantes !== null && kilometrosRestantes <= 0;

      const proximoPorFecha =
        diasRestantes !== null &&
        diasRestantes > 0 &&
        diasRestantes <= 7;

      const proximoPorKilometraje =
        kilometrosRestantes !== null &&
        kilometrosRestantes > 0 &&
        kilometrosRestantes <= 500;

      // ALERTA DE MANTENIMIENTO VENCIDO.
      if (vencidoPorFecha || vencidoPorKilometraje) {
        let descripcion =
          `El mantenimiento preventivo del vehículo ${placas} está vencido.`;

        if (vencidoPorFecha && vencidoPorKilometraje) {
          descripcion +=
            ' Se alcanzó la fecha y el kilometraje programados.';
        } else if (vencidoPorFecha) {
          descripcion += ' Ya se alcanzó la fecha programada.';
        } else {
          descripcion += ' Ya se alcanzó el kilometraje programado.';
        }

        alertas.push({
          vehiculoUid,
          operadorUid,
          placas,
          numeroEconomico,
          mantenimientoUid,
          tipoAlerta: 'preventivo_vencido',
          titulo: 'Mantenimiento preventivo vencido',
          descripcion,
          fechaProgramada,
          kilometrajeProgramado,
          kilometrajeActual,
          diasRestantes,
          kilometrosRestantes,
        });
      }

      // ALERTA DE MANTENIMIENTO PRÓXIMO.
      else if (proximoPorFecha || proximoPorKilometraje) {
        let descripcion =
          `El vehículo ${placas} requiere próximamente ` +
          'un mantenimiento preventivo.';

        if (proximoPorFecha && proximoPorKilometraje) {
          descripcion +=
            ` Faltan ${diasRestantes} días y ` +
            `${kilometrosRestantes} km.`;
        } else if (proximoPorFecha) {
          descripcion += ` Faltan ${diasRestantes} días.`;
        } else {
          descripcion += ` Faltan ${kilometrosRestantes} km.`;
        }

        alertas.push({
          vehiculoUid,
          operadorUid,
          placas,
          numeroEconomico,
          mantenimientoUid,
          tipoAlerta: 'preventivo_proximo',
          titulo: 'Próximo mantenimiento preventivo',
          descripcion,
          fechaProgramada,
          kilometrajeProgramado,
          kilometrajeActual,
          diasRestantes,
          kilometrosRestantes,
        });
      }
    }
  }

  return alertas;
}

// Genera el contenido del correo electrónico.
function generarCorreo(alerta) {
  const titulo = escaparHTML(alerta.titulo);
  const placas = escaparHTML(alerta.placas);
  const numeroEconomico = escaparHTML(alerta.numeroEconomico);
  const descripcion = escaparHTML(alerta.descripcion);

  const fecha = escaparHTML(
    formatearFecha(alerta.fechaProgramada)
  );

  const kilometrajeProgramado =
    alerta.kilometrajeProgramado ?? 'No especificado';

  return {
    subject: `[Parque Vehicular CFE] ${alerta.titulo} - ${alerta.placas}`,

    text:
      `${alerta.titulo}\n\n` +
      `${alerta.descripcion}\n\n` +
      `Placas: ${alerta.placas}\n` +
      `Número económico: ${alerta.numeroEconomico}\n` +
      `Fecha programada: ${fecha}\n` +
      `Kilometraje programado: ${kilometrajeProgramado}\n` +
      `Kilometraje actual: ${alerta.kilometrajeActual} km`,

    html: `
      <div style="
        font-family: Arial, sans-serif;
        max-width: 600px;
        margin: auto;
        padding: 25px;
        border: 1px solid #dddddd;
        border-radius: 10px;
      ">

        <h2 style="color: #008A45;">
          Parque Vehicular CFE
        </h2>

        <h3>${titulo}</h3>

        <p>${descripcion}</p>

        <hr>

        <p><strong>Placas:</strong> ${placas}</p>

        <p>
          <strong>Número económico:</strong>
          ${numeroEconomico}
        </p>

        <p>
          <strong>Fecha programada:</strong>
          ${fecha}
        </p>

        <p>
          <strong>Kilometraje programado:</strong>
          ${escaparHTML(kilometrajeProgramado)} km
        </p>

        <p>
          <strong>Kilometraje actual:</strong>
          ${alerta.kilometrajeActual} km
        </p>

        <hr>

        <p style="color: #666;">
          Este correo fue generado automáticamente
          por el sistema de gestión del parque vehicular.
        </p>

      </div>
    `,
  };
}

// Controla que no se envíe repetidamente la misma alerta.
async function reservarEnvio(alerta) {
  const id = [
    alerta.vehiculoUid,
    alerta.mantenimientoUid,
    alerta.tipoAlerta,
  ].join('_');

  const referencia = db.collection('correo_notificaciones').doc(id);

  const reservado = await db.runTransaction(async transaction => {
    const documento = await transaction.get(referencia);

    const datos = documento.exists ? documento.data() : {};

    if (datos.activo === true) {
      if (datos.enviado === true) {
        return false;
      }

      const ultimoIntento = datos.fechaIntento?.toDate?.();

      if (
        ultimoIntento &&
        Date.now() - ultimoIntento.getTime() < 30 * 60 * 1000
      ) {
        return false;
      }
    }

    transaction.set(referencia, {
      activo: true,
      enviado: false,
      vehiculoUid: alerta.vehiculoUid,
      mantenimientoUid: alerta.mantenimientoUid,
      tipoAlerta: alerta.tipoAlerta,
      fechaIntento: FieldValue.serverTimestamp(),
    }, { merge: true });

    return true;
  });

  return reservado ? referencia : null;
}

// Desactiva alertas que ya no se encuentran vigentes.
async function desactivarAlertasAnteriores(idsActivos) {
  const consulta = await db.collection('correo_notificaciones').get();

  let batch = db.batch();
  let cantidad = 0;

  for (const documento of consulta.docs) {
    if (
      documento.data().activo === true &&
      !idsActivos.has(documento.id)
    ) {
      batch.update(documento.ref, {
        activo: false,
      });

      cantidad++;

      if (cantidad === 450) {
        await batch.commit();
        batch = db.batch();
        cantidad = 0;
      }
    }
  }

  if (cantidad > 0) {
    await batch.commit();
  }
}

// FUNCIÓN PROGRAMADA: TODOS LOS DÍAS A LAS 8:00 AM.
exports.enviarNotificacionesCorreo = onSchedule(
  {
    schedule: '0 08 * * *',
    timeZone: ZONA_HORARIA,
    secrets: [BREVO_SMTP_LOGIN, BREVO_SMTP_KEY, BREVO_FROM_EMAIL],
    maxInstances: 1,
    timeoutSeconds: 540,
  },

  async () => {
    console.log('Iniciando revisión de notificaciones por correo.');

    const correoRemitente = BREVO_FROM_EMAIL.value().replace(/\s/g, '');

    const transporter = nodemailer.createTransport({
      host: 'smtp-relay.brevo.com',
      port: 587,
      secure: false,

      auth: {
        user: BREVO_SMTP_LOGIN.value().replace(/\s/g, ''),
        pass: BREVO_SMTP_KEY.value().replace(/\s/g, ''),
      },
    });

    const alertas = await obtenerAlertasActivas();

    const idsActivos = new Set();

    let enviados = 0;

    for (const alerta of alertas) {
      const id = [
        alerta.vehiculoUid,
        alerta.mantenimientoUid,
        alerta.tipoAlerta,
      ].join('_');

      idsActivos.add(id);

      try {
        // Busca al operador asignado.
        const documentoOperador = await db
          .collection('usuario')
          .doc(alerta.operadorUid)
          .get();

        if (!documentoOperador.exists) {
          console.log('No se encontró el operador:', alerta.operadorUid);
          continue;
        }

        const operador = documentoOperador.data();

        if (operador.rol?.toString().toLowerCase() !== 'operador') {
          continue;
        }

        const correoDestino = operador.correo?.toString().trim();

        if (!correoDestino) {
          console.log('El operador no tiene correo registrado.');
          continue;
        }

        // Reserva el envío para evitar duplicados.
        const referencia = await reservarEnvio(alerta);

        if (!referencia) {
          console.log('La alerta ya fue enviada o está en proceso:', id);
          continue;
        }

        try {
          const contenido = generarCorreo(alerta);

          await transporter.sendMail({
            from: {
              name: 'Parque Vehicular CFE',
              address: correoRemitente,
            },

            to: correoDestino,

            subject: contenido.subject,
            text: contenido.text,
            html: contenido.html,
          });

          await referencia.update({
            enviado: true,
            activo: true,
            enviadoEn: FieldValue.serverTimestamp(),
            correoDestino,
          });

          enviados++;

          console.log('Correo enviado a:', correoDestino);

        } catch (errorEnvio) {
          await referencia.update({
            activo: false,
            enviado: false,
            error: String(errorEnvio.message).substring(0, 500),
          });

          console.error('Error al enviar correo:', errorEnvio);
        }

      } catch (error) {
        console.error(
          'Error procesando la alerta:',
          alerta.mantenimientoUid,
          error
        );
      }
    }

    // Permite volver a notificar si una alerta desapareció
    // y posteriormente vuelve a presentarse.
    await desactivarAlertasAnteriores(idsActivos);

    console.log('================================');
    console.log('REVISIÓN DE CORREOS FINALIZADA');
    console.log('Alertas detectadas:', alertas.length);
    console.log('Correos enviados:', enviados);
    console.log('================================');
  }
);


// ============================================
// RESPALDOS Y RESTAURACIÓN DEL PROYECTO
// ============================================

// Configuración de Google Cloud Run.
const PROYECTO_RESPALDOS = 'p-vehicular';
const REGION_RESPALDOS = 'us-central1';
const BUCKET_RESPALDOS = 'p-vehicular-respaldos-2026';

// Autenticación automática mediante la cuenta de servicio
// asignada a Firebase Cloud Functions.
const googleAuth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

// Ejecuta un trabajo de Cloud Run.
async function ejecutarTrabajoCloudRun(nombreTrabajo, variables = null) {
  const cliente = await googleAuth.getClient();

  const url =
    `https://run.googleapis.com/v2/projects/${PROYECTO_RESPALDOS}` +
    `/locations/${REGION_RESPALDOS}/jobs/${nombreTrabajo}:run`;

  const datosSolicitud = {};

  // Las variables se sobrescriben únicamente durante
  // esta ejecución del trabajo.
  if (variables) {
    datosSolicitud.overrides = {
      containerOverrides: [
        {
          env: Object.entries(variables).map(([nombre, valor]) => ({
            name: nombre,
            value: valor,
          })),
        },
      ],
    };
  }

  const respuesta = await cliente.request({
    url,
    method: 'POST',
    data: datosSolicitud,
  });

  return respuesta.data;
}

// Convierte fechas de Firestore a texto ISO.
function fechaRespaldoISO(valor) {
  if (!valor) return null;

  if (valor.toDate) {
    return valor.toDate().toISOString();
  }

  if (valor instanceof Date) {
    return valor.toISOString();
  }

  return null;
}

// ============================================
// 1. CONSULTAR HISTORIAL DE RESPALDOS
// ============================================

exports.obtenerRespaldos = onCall(
  {
    region: 'us-central1',
  },
  async (request) => {
    await verificarAdministrador(request.auth?.uid);

    try {
      const consulta = await db
        .collection('respaldos')
        .orderBy('fechaInicio', 'desc')
        .limit(100)
        .get();

      const respaldos = consulta.docs.map((documento) => {
        const datos = documento.data();

        return {
          identificador: documento.id,
          fechaInicio: fechaRespaldoISO(datos.fechaInicio),
          fechaFinalizacion: fechaRespaldoISO(
            datos.fechaFinalizacion
          ),
          estado: texto(datos.estado) || 'desconocido',
          proyecto: texto(datos.proyecto),
          bucket: texto(datos.bucket),
          cantidadArchivosStorage:
            Number(datos.cantidadArchivosStorage) || 0,
          cantidadUsuarios:
            Number(datos.cantidadUsuarios) || 0,
          error: texto(datos.error),
          tipo: texto(datos.tipo),
        };
      });

      return {
        correcto: true,
        respaldos,
      };

    } catch (error) {
      console.error('Error al consultar los respaldos:', error);

      throw new HttpsError(
        'internal',
        'No fue posible consultar el historial de respaldos.'
      );
    }
  }
);

// ============================================
// 2. GENERAR UN NUEVO RESPALDO
// ============================================

exports.generarRespaldo = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60,
  },
  async (request) => {
    await verificarAdministrador(request.auth?.uid);

    try {
      const operacion = await ejecutarTrabajoCloudRun(
        'respaldo-vehicular'
      );

      console.log(
        'Solicitud de respaldo enviada a Cloud Run:',
        operacion.name
      );

      return {
        correcto: true,
        mensaje: 'La solicitud de respaldo se inició correctamente.',
        operacion: operacion.name || '',
      };

    } catch (error) {
      console.error('Error al iniciar el respaldo:', error);

      throw new HttpsError(
        'internal',
        'No fue posible iniciar el trabajo de respaldo en Cloud Run.'
      );
    }
  }
);

// ============================================
// 3. RESTAURAR UN RESPALDO EXISTENTE
// ============================================

exports.restaurarRespaldo = onCall(
  {
    region: 'us-central1',
    timeoutSeconds: 60,
  },
  async (request) => {
    await verificarAdministrador(request.auth?.uid);

    const identificador = texto(request.data?.identificador);
    const confirmar = request.data?.confirmar;

    if (!identificador) {
      throw new HttpsError(
        'invalid-argument',
        'Debes seleccionar un respaldo para restaurar.'
      );
    }

    // Evita identificadores que puedan manipular rutas.
    if (
      identificador.length > 80 ||
      !/^[a-zA-Z0-9T._-]+$/.test(identificador) ||
      identificador.includes('..')
    ) {
      throw new HttpsError(
        'invalid-argument',
        'El identificador del respaldo no es válido.'
      );
    }

    if (confirmar !== true) {
      throw new HttpsError(
        'failed-precondition',
        'Debes confirmar la restauración para continuar.'
      );
    }

    try {
      // Comprueba que el respaldo exista en el historial.
      const referencia = db
        .collection('respaldos')
        .doc(identificador);

      const documento = await referencia.get();

      if (!documento.exists) {
        throw new HttpsError(
          'not-found',
          'El respaldo seleccionado no existe.'
        );
      }

      const datos = documento.data();

      // Solo se permiten respaldos completados.
      if (texto(datos.estado).toLowerCase() !== 'completado') {
        throw new HttpsError(
          'failed-precondition',
          'No se puede restaurar un respaldo que no esté completado.'
        );
      }

      // Comprueba que pertenezca al proyecto y bucket esperados.
      if (
        texto(datos.proyecto) !== PROYECTO_RESPALDOS ||
        texto(datos.bucket) !== BUCKET_RESPALDOS
      ) {
        throw new HttpsError(
          'failed-precondition',
          'El respaldo no pertenece al proyecto o bucket esperado.'
        );
      }

      // Ejecuta Cloud Run con las variables necesarias.
      // CONFIRMAR_RESTAURACION solo se establece para esta ejecución.
      const operacion = await ejecutarTrabajoCloudRun(
        'restaurar-vehicular',
        {
          IDENTIFICADOR_RESPALDO: identificador,
          CONFIRMAR_RESTAURACION: 'true',
        }
      );

      console.log(
        'Solicitud de restauración enviada a Cloud Run:',
        identificador,
        operacion.name
      );

      return {
        correcto: true,
        mensaje: 'La solicitud de restauración se inició correctamente.',
        identificador,
        operacion: operacion.name || '',
      };

    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error('Error al iniciar la restauración:', error);

      throw new HttpsError(
        'internal',
        'No fue posible iniciar la restauración en Cloud Run.'
      );
    }
  }
);
