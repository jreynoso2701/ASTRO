/// Prioridades de un ticket en ASTRO.
enum TicketPriority {
  baja('Baja', 1.0),
  media('Media', 3.0),
  alta('Alta', 5.0),
  critica('Crítica', 8.0);

  const TicketPriority(this.label, this.penaltyWeight);
  final String label;

  /// Peso base de penalización al progreso del módulo cuando hay un
  /// ticket abierto con esta prioridad (se modula por impacto y avance).
  final double penaltyWeight;

  /// V1 label stored in Firestore `prioridadIncidente`.
  String get v1Label => switch (this) {
    baja => 'BAJA',
    media => 'NORMAL',
    alta => 'ALTA',
    critica => 'CRITICA',
  };

  static TicketPriority fromString(String value) {
    final upper = value.toUpperCase().trim();
    // V1 uppercase mappings
    if (upper == 'BAJA') return TicketPriority.baja;
    if (upper == 'NORMAL') return TicketPriority.media;
    if (upper == 'ALTA') return TicketPriority.alta;
    if (upper == 'CRITICA' || upper == 'CRÍTICA') return TicketPriority.critica;
    // V2 label / name mappings
    return TicketPriority.values.firstWhere(
      (p) => p.label.toLowerCase() == value.toLowerCase() || p.name == value,
      orElse: () => TicketPriority.media,
    );
  }
}
