/// Estados de un requerimiento en ASTRO.
enum RequerimientoStatus {
  propuesto('Propuesto'),
  enRevision('En Revisión'),
  aprobado('Aprobado'),
  diferido('Diferido'),
  rechazado('Rechazado'),
  enDesarrollo('En Desarrollo'),
  implementado('Implementado'),
  cerrado('Cerrado');

  const RequerimientoStatus(this.label);
  final String label;

  static RequerimientoStatus fromString(String value) {
    return RequerimientoStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == value.toLowerCase() || s.name == value,
      orElse: () => RequerimientoStatus.propuesto,
    );
  }
}
