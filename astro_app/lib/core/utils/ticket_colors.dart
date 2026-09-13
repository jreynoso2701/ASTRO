import 'dart:ui';

import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/ticket_priority.dart';
import 'package:astro/core/models/requerimiento_status.dart';

/// Colores de flujo de trabajo.
///
/// El lenguaje visual reserva el color para significado, así que estos tonos
/// salen todos de la paleta semántica de [AppColors]. Los estados de un mismo
/// flujo necesitan distinguirse entre sí, de modo que se recorre la escala
/// info → caution → warning → success a medida que el trabajo avanza, y el
/// gris queda para lo inactivo.

/// Color asociado a cada estado de ticket.
Color ticketStatusColor(TicketStatus status) {
  return switch (status) {
    TicketStatus.pendiente => AppColors.info,
    TicketStatus.enDesarrollo => AppColors.caution,
    TicketStatus.pruebasInternas => AppColors.warning,
    TicketStatus.pruebasCliente => AppColors.volt,
    TicketStatus.bugs => AppColors.error,
    TicketStatus.resuelto => AppColors.success,
    TicketStatus.archivado => AppColors.grey600,
  };
}

/// Color asociado a cada prioridad de ticket.
Color ticketPriorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.baja => AppColors.success,
    TicketPriority.media => AppColors.info,
    TicketPriority.alta => AppColors.warning,
    TicketPriority.critica => AppColors.error,
  };
}

/// Color asociado a cada estado de requerimiento.
Color reqStatusColor(RequerimientoStatus status) {
  return switch (status) {
    RequerimientoStatus.propuesto => AppColors.grey400,
    RequerimientoStatus.enRevision => AppColors.info,
    RequerimientoStatus.enDesarrollo => AppColors.caution,
    RequerimientoStatus.implementado => AppColors.volt,
    RequerimientoStatus.completado => AppColors.success,
    RequerimientoStatus.descartado => AppColors.error,
  };
}
