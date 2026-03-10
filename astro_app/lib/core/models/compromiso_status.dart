/// Estado de un compromiso asumido en una minuta.
enum CompromisoStatus {
  pendiente('Pendiente'),
  cumplido('Cumplido'),
  vencido('Vencido');

  const CompromisoStatus(this.label);
  final String label;

  factory CompromisoStatus.fromString(String? value) {
    if (value == null || value.isEmpty) return CompromisoStatus.pendiente;
    return CompromisoStatus.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => CompromisoStatus.pendiente,
    );
  }
}
