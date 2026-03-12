/// Estados de un ticket en ASTRO.
enum TicketStatus {
  pendiente('Pendiente'),
  enDesarrollo('En Desarrollo'),
  pruebasInternas('Pruebas Internas'),
  pruebasCliente('Pruebas Cliente'),
  bugs('Bugs'),
  resuelto('Resuelto'),
  archivado('Archivado');

  const TicketStatus(this.label);
  final String label;

  /// V1 label stored in Firestore `estatusIncidente`.
  String get v1Label => switch (this) {
    pendiente => 'PENDIENTE',
    enDesarrollo => 'EN DESARROLLO',
    pruebasInternas => 'PRUEBAS INTERNAS',
    pruebasCliente => 'PRUEBAS CLIENTE',
    bugs => 'BUGS',
    resuelto => 'RESUELTO',
    archivado => 'CERRADO',
  };

  /// Whether this status should appear as a Kanban column.
  bool get isKanbanVisible => this != archivado;

  /// Kanban-visible statuses (excludes Archivado).
  static List<TicketStatus> get kanbanValues =>
      values.where((s) => s.isKanbanVisible).toList();

  static TicketStatus fromString(String value) {
    final upper = value.toUpperCase().trim();
    // V1 uppercase mappings (backward compat)
    if (upper == 'PENDIENTE') return TicketStatus.pendiente;
    if (upper == 'EN PROCESO') return TicketStatus.enDesarrollo;
    if (upper == 'EN DESARROLLO') return TicketStatus.enDesarrollo;
    if (upper == 'PRUEBAS INTERNAS') return TicketStatus.pruebasInternas;
    if (upper == 'PRUEBAS CLIENTE') return TicketStatus.pruebasCliente;
    if (upper == 'BUGS') return TicketStatus.bugs;
    if (upper == 'RESUELTO') return TicketStatus.resuelto;
    if (upper == 'CERRADO') return TicketStatus.archivado;
    if (upper == 'ARCHIVADO') return TicketStatus.archivado;
    // V2 label / name mappings
    return TicketStatus.values.firstWhere(
      (s) => s.label.toLowerCase() == value.toLowerCase() || s.name == value,
      orElse: () => TicketStatus.pendiente,
    );
  }
}
