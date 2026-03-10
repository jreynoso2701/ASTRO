/// Modalidad de una reunión / cita.
enum MinutaModalidad {
  videoconferencia('Videoconferencia'),
  presencial('Presencial'),
  llamada('Llamada'),
  hibrida('Híbrida');

  const MinutaModalidad(this.label);
  final String label;

  factory MinutaModalidad.fromString(String? value) {
    if (value == null || value.isEmpty) return MinutaModalidad.videoconferencia;
    return MinutaModalidad.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => MinutaModalidad.videoconferencia,
    );
  }
}
