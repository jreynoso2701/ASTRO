/// Estados de un requerimiento en ASTRO.
enum RequerimientoStatus {
  propuesto('Propuesto'),
  enRevision('En Revisión'),
  enDesarrollo('En Desarrollo'),
  implementado('Implementado'),
  completado('Completado'),
  descartado('Descartado');

  const RequerimientoStatus(this.label);
  final String label;

  /// Valores que representan estados activos (para Kanban, filtros, etc.).
  static const kanbanValues = [
    propuesto,
    enRevision,
    enDesarrollo,
    implementado,
    completado,
    descartado,
  ];

  static RequerimientoStatus fromString(String value) {
    // Backward compat: mapear estados legacy
    final lower = value.toLowerCase();
    if (lower == 'aprobado') return enDesarrollo;
    if (lower == 'diferido') return propuesto;
    if (lower == 'rechazado') return descartado;
    if (lower == 'cerrado') return completado;

    return RequerimientoStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == lower || s.name == value,
      orElse: () => RequerimientoStatus.propuesto,
    );
  }
}
