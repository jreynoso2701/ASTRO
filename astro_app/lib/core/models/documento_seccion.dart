/// Secciones de documentación del proyecto.
enum DocumentoSeccion {
  formal('Formal'),
  compartido('Compartido');

  const DocumentoSeccion(this.label);

  final String label;

  static DocumentoSeccion fromString(String value) {
    return DocumentoSeccion.values.firstWhere(
      (s) => s.label.toLowerCase() == value.toLowerCase(),
      orElse: () => DocumentoSeccion.compartido,
    );
  }
}
