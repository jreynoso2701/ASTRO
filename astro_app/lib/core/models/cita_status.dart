/// Estado de una cita programada.
enum CitaStatus {
  programada('Programada'),
  enCurso('En Curso'),
  completada('Completada'),
  cancelada('Cancelada');

  const CitaStatus(this.label);
  final String label;

  factory CitaStatus.fromString(String? value) {
    if (value == null || value.isEmpty) return CitaStatus.programada;
    return CitaStatus.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => CitaStatus.programada,
    );
  }
}
