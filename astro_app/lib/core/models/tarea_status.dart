/// Estados de una tarea en ASTRO.
enum TareaStatus {
  pendiente('Pendiente'),
  enProgreso('En Progreso'),
  completada('Completada'),
  cancelada('Cancelada');

  const TareaStatus(this.label);
  final String label;

  factory TareaStatus.fromString(String? value) {
    if (value == null || value.isEmpty) return TareaStatus.pendiente;
    return TareaStatus.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => TareaStatus.pendiente,
    );
  }
}
