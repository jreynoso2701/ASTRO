import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';

/// Tipos de referencia soportados.
enum RefType { ticket, requerimiento, minuta, cita }

/// Widget que resuelve un ID de referencia a su folio (y opcionalmente título).
///
/// Usa los providers `*ByIdProvider` para obtener el documento y mostrar
/// el folio en lugar del UUID crudo.
class ResolvedRefText extends ConsumerWidget {
  const ResolvedRefText({
    required this.id,
    required this.type,
    this.style,
    this.showTitle = false,
    this.maxLines = 1,
    super.key,
  });

  final String id;
  final RefType type;
  final TextStyle? style;
  final bool showTitle;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String? folio, String? titulo, bool isLoading) = switch (type) {
      RefType.ticket => () {
        final a = ref.watch(ticketByIdProvider(id));
        return (a.asData?.value?.folio, a.asData?.value?.titulo, a.isLoading);
      }(),
      RefType.requerimiento => () {
        final a = ref.watch(requerimientoByIdProvider(id));
        return (a.asData?.value?.folio, a.asData?.value?.titulo, a.isLoading);
      }(),
      RefType.minuta => () {
        final a = ref.watch(minutaByIdProvider(id));
        return (a.asData?.value?.folio, a.asData?.value?.objetivo, a.isLoading);
      }(),
      RefType.cita => () {
        final a = ref.watch(citaByIdProvider(id));
        return (a.asData?.value?.folio, a.asData?.value?.titulo, a.isLoading);
      }(),
    };

    if (isLoading && folio == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }

    if (folio == null) {
      final fallback = id.length > 8 ? '${id.substring(0, 8)}…' : id;
      return Text(fallback, style: style);
    }

    final text = showTitle && titulo != null ? '$folio — $titulo' : folio;
    return Text(
      text,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: maxLines,
    );
  }
}
