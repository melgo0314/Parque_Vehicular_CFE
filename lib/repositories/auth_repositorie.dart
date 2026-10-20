
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:p_vehicular/models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Iniciar sesión con Firebase Authentication.
  Future<UserCredential> loginWithEmail(
    String correo,
    String contrasena,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  // Buscar los datos del usuario en la colección "usuario".
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

  // Cerrar la sesión actual.
  Future<void> logout() async {
    await _auth.signOut();
  }
}
