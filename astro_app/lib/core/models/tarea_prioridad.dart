/// Prioridades de una tarea en ASTRO.
enum TareaPrioridad {
  baja('Baja'),
  media('Media'),
  alta('Alta'),
  urgente('Urgente');

  const TareaPrioridad(this.label);
  final String label;

  factory TareaPrioridad.fromString(String? value) {
    if (value == null || value.isEmpty) return TareaPrioridad.media;
    return TareaPrioridad.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => TareaPrioridad.media,
    );
  }
}
