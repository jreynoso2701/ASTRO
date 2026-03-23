import 'dart:ui';

import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/requerimiento_status.dart';

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

/// Color asociado a cada estado de requerimiento.
Color reqStatusColor(RequerimientoStatus status) {
  return switch (status) {
    RequerimientoStatus.propuesto => const Color(0xFF90A4AE),
    RequerimientoStatus.enRevision => const Color(0xFF42A5F5),
    RequerimientoStatus.enDesarrollo => const Color(0xFFFFC107),
    RequerimientoStatus.implementado => const Color(0xFF4CAF50),
    RequerimientoStatus.completado => const Color(0xFF388E3C),
    RequerimientoStatus.descartado => const Color(0xFFEF5350),
  };
}
