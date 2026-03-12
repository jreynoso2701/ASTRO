import 'dart:ui';

import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';

/// Color asociado a cada estado de ticket.
Color ticketStatusColor(TicketStatus status) {
  return switch (status) {
    TicketStatus.pendiente => const Color(0xFF2196F3), // Blue
    TicketStatus.enDesarrollo => const Color(0xFF00BCD4), // Cyan
    TicketStatus.pruebasInternas => const Color(0xFFFF9800), // Orange
    TicketStatus.pruebasCliente => const Color(0xFFFFC107), // Amber
    TicketStatus.bugs => const Color(0xFFD71921), // Red
    TicketStatus.resuelto => const Color(0xFF4CAF50), // Green
    TicketStatus.archivado => const Color(0xFF9E9E9E), // Grey
  };
}

/// Color asociado a cada prioridad de ticket.
Color ticketPriorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.baja => const Color(0xFF4CAF50),
    TicketPriority.media => const Color(0xFF2196F3),
    TicketPriority.alta => const Color(0xFFFFC107),
    TicketPriority.critica => const Color(0xFFD71921),
  };
}
