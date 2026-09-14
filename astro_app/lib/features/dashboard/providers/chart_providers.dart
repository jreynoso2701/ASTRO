import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/models/ticket_status.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';

/// Altas y cierres de tickets en un mes concreto.
class TicketMonthFlow {
  const TicketMonthFlow({
    required this.month,
    required this.opened,
    required this.closed,
  });

  /// Primer dia del mes, para poder ordenar y etiquetar.
  final DateTime month;

  /// Tickets creados dentro del mes.
  final int opened;

  /// Tickets que pasaron a resuelto o archivado dentro del mes.
  final int closed;

  /// Diferencia del mes: positiva si entraron mas tickets de los que se
  /// cerraron. Es la lectura que interesa, no cada barra por separado.
  int get net => opened - closed;
}

/// Numero de meses que abarca la grafica de flujo.
const int _flowMonths = 12;

/// Fecha en la que un ticket se dio por cerrado.
///
/// `closedAt` solo esta relleno en una parte de los tickets historicos, asi
/// que para el resto se usa `updatedAt`: es exacto mientras nadie vuelva a
/// tocar el ticket despues de cerrarlo. La grafica se etiqueta como
/// aproximada por este motivo.
DateTime? _closedDate(Ticket t) {
  if (t.status != TicketStatus.resuelto && t.status != TicketStatus.archivado) {
    return null;
  }
  return t.closedAt ?? t.updatedAt;
}

/// Altas frente a cierres por mes, de los ultimos [_flowMonths] meses.
///
/// Contesta si el equipo gana o pierde terreno, que es algo que ningun
/// contador del dashboard dice hoy: un numero de tickets abiertos alto puede
/// significar tanto una mala racha como un mes con mucha entrada.
///
/// Recibe los proyectos ya filtrados en vez de leerlos por su cuenta: la
/// grafica vive dentro de la pestana de Tickets y tiene que responder al
/// selector "Todos los proyectos" igual que el resto de la pestana.
List<TicketMonthFlow> ticketFlowByMonth(WidgetRef ref, List<Proyecto> projects) {
  final now = DateTime.now();
  final firstMonth = DateTime(now.year, now.month - (_flowMonths - 1));

  // Se parte de los meses vacios para que un mes sin movimiento aparezca como
  // un hueco real y no se salte, que deformaria la linea de tiempo.
  final opened = <DateTime, int>{};
  final closed = <DateTime, int>{};
  for (var i = 0; i < _flowMonths; i++) {
    final m = DateTime(firstMonth.year, firstMonth.month + i);
    opened[m] = 0;
    closed[m] = 0;
  }

  DateTime? bucket(DateTime? date) {
    if (date == null) return null;
    final m = DateTime(date.year, date.month);
    return opened.containsKey(m) ? m : null;
  }

  for (final p in projects) {
    final tickets =
        ref.watch(ticketsByProjectProvider(p.nombreProyecto)).value ?? [];
    for (final t in tickets) {
      final alta = bucket(t.createdAt);
      if (alta != null) opened[alta] = opened[alta]! + 1;

      final cierre = bucket(_closedDate(t));
      if (cierre != null) closed[cierre] = closed[cierre]! + 1;
    }
  }

  final months = opened.keys.toList()..sort();
  return [
    for (final m in months)
      TicketMonthFlow(month: m, opened: opened[m]!, closed: closed[m]!),
  ];
}

/// Tickets visibles por estado, contando solo los proyectos indicados.
///
/// Misma razon que [ticketFlowByMonth]: el conteo global ignoraba el filtro.
Map<TicketStatus, int> ticketCountsByStatusFor(
  WidgetRef ref,
  List<Proyecto> projects,
) {
  final counts = <TicketStatus, int>{
    for (final status in TicketStatus.kanbanValues) status: 0,
  };
  for (final p in projects) {
    final tickets =
        ref.watch(ticketsByProjectProvider(p.nombreProyecto)).value ?? [];
    for (final t in tickets) {
      if (t.status.isKanbanVisible) {
        counts[t.status] = (counts[t.status] ?? 0) + 1;
      }
    }
  }
  return counts;
}
