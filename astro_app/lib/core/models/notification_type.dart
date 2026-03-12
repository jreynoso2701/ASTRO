/// Tipos de notificación del sistema ASTRO.
enum NotificationType {
  // Tickets
  ticketCreado('ticket_creado', 'Ticket creado'),
  ticketStatusCambiado('ticket_status', 'Estado de ticket cambiado'),
  ticketAsignado('ticket_asignado', 'Ticket asignado'),
  ticketComentario('ticket_comentario', 'Nuevo comentario en ticket'),
  ticketPrioridadCambiada('ticket_prioridad', 'Prioridad de ticket cambiada'),

  // Requerimientos
  reqCreado('req_creado', 'Requerimiento creado'),
  reqStatusCambiado('req_status', 'Estado de requerimiento cambiado'),
  reqAsignado('req_asignado', 'Requerimiento asignado'),
  reqComentario('req_comentario', 'Nuevo comentario en requerimiento'),
  reqFaseAsignada('req_fase', 'Fase asignada a requerimiento'),

  // Deadline de tickets
  ticketDeadlineAmber('ticket_deadline_amber', 'Ticket próximo a vencer'),
  ticketDeadlineOrange('ticket_deadline_orange', 'Ticket vence hoy/mañana'),
  ticketDeadlineRed('ticket_deadline_red', 'Ticket vencido');

  const NotificationType(this.value, this.label);
  final String value;
  final String label;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationType.ticketCreado,
    );
  }
}

/// Referencia al recurso que originó la notificación.
enum NotificationRefType {
  ticket('ticket'),
  requerimiento('requerimiento'),
  cita('cita');

  const NotificationRefType(this.value);
  final String value;

  static NotificationRefType fromString(String value) {
    return NotificationRefType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationRefType.ticket,
    );
  }
}
