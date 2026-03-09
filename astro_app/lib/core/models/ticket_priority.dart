/// Prioridades de un ticket en ASTRO.
enum TicketPriority {
  baja('Baja'),
  media('Media'),
  alta('Alta'),
  critica('Crítica');

  const TicketPriority(this.label);
  final String label;

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
