import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/app_user.dart';

/// Repositorio para operaciones CRUD de usuarios en Firestore.
///
/// Lee documentos existentes (V1) y escribe en formato V2.
/// **No borra campos legacy** — solo agrega/actualiza campos V2.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Obtiene un usuario por UID.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromFirestore(doc);
  }

  /// Stream de un usuario específico.
  Stream<AppUser?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  /// Lista todos los usuarios activos.
  Future<List<AppUser>> getActiveUsers() async {
    final snapshot = await _usersRef.where('isActive', isEqualTo: true).get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  /// Stream de todos los usuarios.
  Stream<List<AppUser>> watchAllUsers() {
    return _usersRef.snapshots().map(
      (snapshot) => snapshot.docs.map(AppUser.fromFirestore).toList(),
    );
  }

  /// Crea o actualiza el documento de usuario (merge para preservar V1).
  ///
  /// Usa `SetOptions(merge: true)` para **no borrar** campos legacy existentes.
  Future<void> setUser(AppUser user) async {
    await _usersRef
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Actualiza campos específicos sin sobreescribir el resto.
  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _usersRef.doc(uid).update(fields);
  }

  /// Desactiva un usuario (soft delete).
  Future<void> deactivateUser(String uid) async {
    await _usersRef.doc(uid).update({'isActive': false});
  }

  /// Reactiva un usuario.
  Future<void> activateUser(String uid) async {
    await _usersRef.doc(uid).update({'isActive': true});
  }

  /// Busca usuarios por nombre o email.
  Future<List<AppUser>> searchUsers(String query) async {
    final upperQuery = query.toUpperCase();
    // Firestore no soporta búsqueda full-text, hacemos client-side filter
    final snapshot = await _usersRef.get();
    return snapshot.docs
        .map(AppUser.fromFirestore)
        .where(
          (u) =>
              u.displayName.toUpperCase().contains(upperQuery) ||
              u.email.toUpperCase().contains(upperQuery),
        )
        .toList();
  }

  /// Obtiene usuarios de una empresa específica (campo legacy V1).
  Future<List<AppUser>> getUsersByEmpresa(String empresaName) async {
    final snapshot = await _usersRef
        .where('deEmpresa', isEqualTo: empresaName)
        .get();
    return snapshot.docs.map(AppUser.fromFirestore).toList();
  }

  /// Crea el documento del usuario si aún no existe en Firestore.
  /// Retorna `true` si se creó un documento nuevo.
  Future<bool> ensureUserExists({
    required String uid,
    required String displayName,
    required String email,
    String? photoUrl,
  }) async {
    final doc = await _usersRef.doc(uid).get();
    if (doc.exists) return false;

    final now = DateTime.now();
    await setUser(
      AppUser(
        uid: uid,
        displayName: displayName,
        email: email,
        photoUrl: photoUrl,
        isActive: true,
        isRoot: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return true;
  }

  /// Actualiza nombre, teléfono y/o foto de un usuario.
  Future<void> updateProfile(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    if (displayName == null && phoneNumber == null && photoUrl == null) return;
    final fields = <String, dynamic>{'updatedAt': Timestamp.now()};
    if (displayName != null) fields['displayName'] = displayName;
    if (phoneNumber != null) fields['phoneNumber'] = phoneNumber;
    if (photoUrl != null) fields['photoUrl'] = photoUrl;
    await _usersRef.doc(uid).update(fields);
  }
}
