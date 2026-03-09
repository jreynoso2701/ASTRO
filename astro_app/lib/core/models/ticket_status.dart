/// Estados de un ticket en ASTRO.
enum TicketStatus {
  abierto('Abierto'),
  enProgreso('En Progreso'),
  resuelto('Resuelto'),
  cerrado('Cerrado');

  const TicketStatus(this.label);
  final String label;

  /// V1 label stored in Firestore `estatusIncidente`.
  String get v1Label => switch (this) {
    abierto => 'PENDIENTE',
    enProgreso => 'EN PROCESO',
    resuelto => 'RESUELTO',
    cerrado => 'CERRADO',
  };

  static TicketStatus fromString(String value) {
    final upper = value.toUpperCase().trim();
    // V1 uppercase mappings
    if (upper == 'PENDIENTE') return TicketStatus.abierto;
    if (upper == 'EN PROCESO') return TicketStatus.enProgreso;
    if (upper == 'RESUELTO') return TicketStatus.resuelto;
    if (upper == 'CERRADO') return TicketStatus.cerrado;
    // V2 label / name mappings
    return TicketStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == value.toLowerCase() || s.name == value,
      orElse: () => TicketStatus.abierto,
    );
  }
}
