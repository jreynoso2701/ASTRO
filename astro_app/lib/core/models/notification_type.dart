/// Tipos de notificación del sistema ASTRO.
enum NotificationType {
  // Tickets
  ticketCreado('ticket_creado', 'Ticket creado'),
  ticketStatusCambiado('ticket_status', 'Estado de ticket cambiado'),
  ticketAsignado('ticket_asignado', 'Ticket asignado'),
  ticketComentario('ticket_comentario', 'Nuevo comentario en ticket'),
  ticketPrioridadCambiada('ticket_prioridad', 'Prioridad de ticket cambiada'),
  ticketFechaCompromiso(
    'ticket_fecha_compromiso',
    'Fecha compromiso de ticket cambiada',
  ),

  // Requerimientos
  reqCreado('req_creado', 'Requerimiento creado'),
  reqStatusCambiado('req_status', 'Estado de requerimiento cambiado'),
  reqAsignado('req_asignado', 'Requerimiento asignado'),
  reqComentario('req_comentario', 'Nuevo comentario en requerimiento'),
  reqFaseAsignada('req_fase', 'Fase asignada a requerimiento'),
  reqPrioridadCambiada('req_prioridad', 'Prioridad de requerimiento cambiada'),
  reqFechaCompromiso(
    'req_fecha_compromiso',
    'Fecha compromiso de requerimiento cambiada',
  ),

  // Deadline de requerimientos
  reqDeadlineAmber('req_deadline_amber', 'Requerimiento próximo a vencer'),
  reqDeadlineOrange('req_deadline_orange', 'Requerimiento vence hoy/mañana'),
  reqDeadlineRed('req_deadline_red', 'Requerimiento vencido'),

  // Deadline de tickets
  ticketDeadlineAmber('ticket_deadline_amber', 'Ticket próximo a vencer'),
  ticketDeadlineOrange('ticket_deadline_orange', 'Ticket vence hoy/mañana'),
  ticketDeadlineRed('ticket_deadline_red', 'Ticket vencido'),

  // Tareas
  tareaCreada('tarea_creada', 'Tarea creada'),
  tareaStatusCambiada('tarea_status', 'Estado de tarea cambiado'),
  tareaAsignada('tarea_asignada', 'Tarea asignada'),

  // Deadline de tareas
  tareaDeadlineAmber('tarea_deadline_amber', 'Tarea próxima a vencer'),
  tareaDeadlineOrange('tarea_deadline_orange', 'Tarea vence hoy/mañana'),
  tareaDeadlineRed('tarea_deadline_red', 'Tarea vencida'),

  // Compromisos deadline
  compromisoDeadlineAmber(
    'compromiso_deadline_amber',
    'Compromiso próximo a vencer',
  ),
  compromisoDeadlineOrange(
    'compromiso_deadline_orange',
    'Compromiso vence hoy/mañana',
  ),
  compromisoDeadlineRed('compromiso_deadline_red', 'Compromiso vencido'),

  // Citas
  citaCreada('cita_creada', 'Cita creada'),
  citaActualizada('cita_actualizada', 'Cita actualizada'),
  citaCancelada('cita_cancelada', 'Cita cancelada'),
  citaCompletada('cita_completada', 'Cita completada'),
  citaRecordatorio('cita_recordatorio', 'Recordatorio de cita');

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
  cita('cita'),
  minuta('minuta'),
  tarea('tarea');

  const NotificationRefType(this.value);
  final String value;

  static NotificationRefType fromString(String value) {
    return NotificationRefType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationRefType.ticket,
    );
  }
}
