import 'package:firebase_auth/firebase_auth.dart';

/// Repositorio de autenticación — encapsula Firebase Auth (email/contraseña).
class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  /// Stream del estado de autenticación.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Usuario actual (null si no hay sesión).
  User? get currentUser => _firebaseAuth.currentUser;

  /// Iniciar sesión con email y contraseña.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Registrar con email y contraseña.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Enviar correo de recuperación de contraseña.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Verifica si el usuario actual usa email/password.
  bool get isPasswordUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'password');
  }

  /// Actualiza el perfil de Firebase Auth (displayName y/o photoURL).
  Future<void> updateAuthProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    if (displayName != null) await user.updateDisplayName(displayName);
    if (photoURL != null) await user.updatePhotoURL(photoURL);
  }

  /// Re-autentica al usuario con email y contraseña (necesario antes de cambiar password o eliminar cuenta).
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Cambia la contraseña del usuario actual.
  Future<void> updatePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    await user.updatePassword(newPassword);
  }

  /// Elimina la cuenta de Firebase Auth del usuario actual.
  /// Requiere re-autenticación previa.
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    await user.delete();
  }

  /// Cerrar sesión.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
