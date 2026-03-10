/// Categorías por defecto de documentos formales.
enum DocumentoCategoria {
  memoriaTecnica('Memoria Técnica'),
  contrato('Contrato'),
  polizaSoporte('Póliza de Soporte'),
  relacionUsuarios('Relación de Usuarios'),
  manualUsuario('Manual de Usuario'),
  actaEntrega('Acta de Entrega'),
  minuta('Minuta'),
  otro('Otro');

  const DocumentoCategoria(this.label);

  final String label;

  static DocumentoCategoria fromString(String value) {
    return DocumentoCategoria.values.firstWhere(
      (c) => c.label.toLowerCase() == value.toLowerCase(),
      orElse: () => DocumentoCategoria.otro,
    );
  }

  /// Todas las categorías por defecto como lista de strings.
  static List<String> get defaultLabels =>
      DocumentoCategoria.values.map((c) => c.label).toList();
}
