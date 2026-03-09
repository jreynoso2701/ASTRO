/// Fase asignada a un requerimiento aprobado.
enum RequerimientoFase {
  faseActual('Fase Actual'),
  proximaFase('Próxima Fase');

  const RequerimientoFase(this.label);
  final String label;

  static RequerimientoFase? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    return RequerimientoFase.values.firstWhere(
      (f) => f.label.toLowerCase() == value.toLowerCase() || f.name == value,
      orElse: () => RequerimientoFase.faseActual,
    );
  }
}
