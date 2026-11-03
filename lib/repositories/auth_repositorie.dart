import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:p_vehicular/models/user_model.dart';

// Se comunica con Firebase Authentication y Cloud Firestore.
class AuthRepository {
  // Servicio de Firebase Authentication.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Servicio de Cloud Firestore.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Inicia sesión con el correo y la contraseña proporcionados.
  // Entradas: correo y contrasena del usuario.
  // Salida: las credenciales de Firebase del usuario autenticado.
  Future<UserCredential> loginWithEmail(
    String correo,
    String contrasena,
  ) async {
    return _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  // Busca los datos del usuario en la colección "usuario".
  // Entrada: uid, identificador único del usuario.
  // Salida: el modelo del usuario si existe; de lo contrario, null.
  Future<UserModel?> getUserData(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _db.collection('usuario').doc(uid).get();

    if (!doc.exists) {
      return null;
    }

    final datos = doc.data();

    if (datos == null) {
      return null;
    }

    return UserModel.fromMap(datos, doc.id);
  }

  // Cierra la sesión actual de Firebase Authentication.
  // Entrada: ninguna.
  // Salida: ninguna; completa cuando Firebase cierra la sesión.
  Future<void> logout() async {
    await _auth.signOut();
  }
}