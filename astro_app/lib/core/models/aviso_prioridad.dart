/// Nivel de prioridad de un aviso.
enum AvisoPrioridad {
  informativo('informativo', 'Informativo'),
  importante('importante', 'Importante'),
  urgente('urgente', 'Urgente');

  const AvisoPrioridad(this.value, this.label);
  final String value;
  final String label;

  static AvisoPrioridad fromString(String value) {
    return AvisoPrioridad.values.firstWhere(
      (p) => p.value == value,
      orElse: () => AvisoPrioridad.informativo,
    );
  }
}
