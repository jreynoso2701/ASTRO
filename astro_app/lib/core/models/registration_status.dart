/// Estado de registro/aprobación de un usuario en ASTRO.
enum RegistrationStatus {
  pending('pending', 'Pendiente'),
  approved('approved', 'Aprobado'),
  rejected('rejected', 'Rechazado');

  const RegistrationStatus(this.value, this.label);

  /// Valor almacenado en Firestore.
  final String value;

  /// Etiqueta para mostrar en UI.
  final String label;

  /// Crea un [RegistrationStatus] a partir de un string de Firestore.
  /// Usuarios existentes sin campo → se consideran `approved`.
  static RegistrationStatus fromString(String? value) {
    if (value == null) return RegistrationStatus.approved;
    return RegistrationStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => RegistrationStatus.approved,
    );
  }
}
