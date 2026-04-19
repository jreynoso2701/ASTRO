/// Roles del sistema ASTRO.
enum UserRole {
  root('Root'),
  liderProyecto('Lider Proyecto'),
  supervisor('Supervisor'),
  usuario('Usuario'),
  soporte('Soporte');

  const UserRole(this.label);

  /// Etiqueta para mostrar en UI.
  final String label;

  /// Crea un [UserRole] a partir de un string de Firestore.
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.label.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.usuario,
    );
  }
}
