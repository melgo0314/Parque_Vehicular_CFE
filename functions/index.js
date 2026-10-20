const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

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
      // La cuenta y el perfil ya se eliminaron; registrar si falla la limpieza.
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