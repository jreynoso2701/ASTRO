/// Tipos de requerimiento en ASTRO.
enum RequerimientoTipo {
  funcional('Funcional'),
  noFuncional('No Funcional');

  const RequerimientoTipo(this.label);
  final String label;

  static RequerimientoTipo fromString(String value) {
    return RequerimientoTipo.values.firstWhere(
      (t) => t.label.toLowerCase() == value.toLowerCase() || t.name == value,
      orElse: () => RequerimientoTipo.funcional,
    );
  }
}
