import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:astro/core/models/minuta.dart';
import 'package:astro/core/models/compromiso_status.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/core/services/minuta_pdf_service.dart';
import 'package:astro/features/minutas/providers/minuta_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de detalle de una minuta de reunión.
class MinutaDetailScreen extends ConsumerWidget {
  const MinutaDetailScreen({
    required this.projectId,
    required this.minutaId,
    super.key,
  });

  final String projectId;
  final String minutaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutaAsync = ref.watch(minutaByIdProvider(minutaId));
    final canManage = ref.watch(canManageProjectProvider(projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MINUTA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/projects/$projectId/minutas'),
        ),
        actions: [
          minutaAsync.whenOrNull(
                data: (m) => m != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            tooltip: 'Imprimir / PDF',
                            onPressed: () => _printPdf(m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: 'Compartir PDF',
                            onPressed: () => _sharePdf(m),
                          ),
                          if (canManage || isRoot)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Editar minuta',
                              onPressed: () => context.go(
                                '/projects/$projectId/minutas/$minutaId/edit',
                              ),
                            ),
                        ],
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: minutaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (minuta) {
          if (minuta == null) {
            return const Center(child: Text('Minuta no encontrada'));
          }

          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _MinutaInfoSection(minuta: minuta);
          final compromisosSection = _CompromisosSection(
            minuta: minuta,
            canManage: canManage || isRoot,
            onToggleCompromiso: (index) =>
                _toggleCompromiso(ref, minuta, index),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: infoSection,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: compromisosSection,
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoSection,
                const SizedBox(height: 24),
                compromisosSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleCompromiso(
    WidgetRef ref,
    Minuta minuta,
    int index,
  ) async {
    final compromiso = minuta.compromisos[index];
    final newStatus = compromiso.status == CompromisoStatus.cumplido
        ? CompromisoStatus.pendiente
        : CompromisoStatus.cumplido;

    final updated = List<CompromisoMinuta>.from(minuta.compromisos);
    updated[index] = compromiso.copyWith(status: newStatus);

    final repo = ref.read(minutaRepositoryProvider);
    await repo.update(minuta.copyWith(compromisos: updated));
  }

  Future<void> _printPdf(Minuta minuta) async {
    final pdf = await MinutaPdfService.generate(minuta);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Minuta_${minuta.folio}',
    );
  }

  Future<void> _sharePdf(Minuta minuta) async {
    final pdf = await MinutaPdfService.generate(minuta);
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Minuta_${minuta.folio}.pdf',
    );
  }
}

// ── Info Section ─────────────────────────────────────────

class _MinutaInfoSection extends StatelessWidget {
  const _MinutaInfoSection({required this.minuta});

  final Minuta minuta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = minuta.fecha != null
        ? DateFormat('dd/MM/yyyy').format(minuta.fecha!)
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.08,
                ),
                child: const Icon(Icons.description_outlined, size: 32),
              ),
              const SizedBox(height: 12),
              Text('MINUTA DE REUNIÓN', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  minuta.folio,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INFORMACIÓN',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                _InfoRow(label: 'Versión', value: minuta.version),
                _InfoRow(label: 'Fecha', value: dateStr),
                _InfoRow(
                  label: 'Hora',
                  value:
                      '${minuta.horaInicio ?? '—'} – ${minuta.horaFin ?? '—'}',
                ),
                _InfoRow(label: 'Modalidad', value: minuta.modalidad.label),
                if (minuta.lugar != null && minuta.lugar!.isNotEmpty)
                  _InfoRow(label: 'Lugar', value: minuta.lugar!),
                if (minuta.urlVideoconferencia != null &&
                    minuta.urlVideoconferencia!.isNotEmpty)
                  _InfoRow(label: 'URL', value: minuta.urlVideoconferencia!),
                if (minuta.direccion != null && minuta.direccion!.isNotEmpty)
                  _InfoRow(label: 'Dirección', value: minuta.direccion!),
                _InfoRow(label: 'Empresa', value: minuta.empresaName),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Objetivo
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBJETIVO',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                Text(minuta.objetivo, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Asistentes
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASISTENTES',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                if (minuta.asistentes.isEmpty)
                  Text(
                    'Sin asistentes registrados',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...minuta.asistentes.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            a.asistencia
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 18,
                            color: a.asistencia
                                ? const Color(0xFF4CAF50)
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.nombre,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  a.puesto,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Asuntos tratados
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASUNTOS TRATADOS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                if (minuta.asuntosTratados.isEmpty)
                  Text(
                    'Sin asuntos registrados',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...minuta.asuntosTratados.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.numero}. ${a.texto}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (a.subitems.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 24, top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: a.subitems
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          '${String.fromCharCode(97 + e.key)}. ${e.value}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Observaciones
        if (minuta.observaciones != null &&
            minuta.observaciones!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OBSERVACIONES',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    minuta.observaciones!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],

        // Adjuntos
        if (minuta.adjuntos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADJUNTOS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  ...minuta.adjuntos.map((url) {
                    final decoded = Uri.decodeFull(url);
                    final name = decoded.split('/').last.split('?').first;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attachment,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],

        // Tickets vinculados
        if (minuta.refTickets.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TICKETS VINCULADOS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  ...minuta.refTickets.map(
                    (id) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.confirmation_num_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              id,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Requerimientos vinculados
        if (minuta.refRequerimientos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REQUERIMIENTOS VINCULADOS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  ...minuta.refRequerimientos.map(
                    (id) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              id,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Resumen IA
        if (minuta.resumenIA != null && minuta.resumenIA!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RESUMEN IA',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(minuta.resumenIA!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Compromisos Section ──────────────────────────────────

class _CompromisosSection extends StatelessWidget {
  const _CompromisosSection({
    required this.minuta,
    required this.canManage,
    required this.onToggleCompromiso,
  });

  final Minuta minuta;
  final bool canManage;
  final ValueChanged<int> onToggleCompromiso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPROMISOS ASUMIDOS',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Divider(),
        if (minuta.compromisos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Sin compromisos registrados',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...minuta.compromisos.asMap().entries.map(
            (e) => _CompromisoTile(
              compromiso: e.value,
              canManage: canManage,
              onToggle: () => onToggleCompromiso(e.key),
            ),
          ),
      ],
    );
  }
}

class _CompromisoTile extends StatelessWidget {
  const _CompromisoTile({
    required this.compromiso,
    required this.canManage,
    required this.onToggle,
  });

  final CompromisoMinuta compromiso;
  final bool canManage;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCumplido = compromiso.status == CompromisoStatus.cumplido;
    final isVencido = compromiso.status == CompromisoStatus.vencido;
    final fechaStr = compromiso.fechaEntrega != null
        ? DateFormat('dd/MM/yyyy').format(compromiso.fechaEntrega!)
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isVencido
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
          : isCumplido
          ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canManage)
              IconButton(
                icon: Icon(
                  isCumplido
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCumplido
                      ? const Color(0xFF4CAF50)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onToggle,
                tooltip: isCumplido ? 'Marcar pendiente' : 'Marcar cumplido',
              )
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isCumplido
                      ? Icons.check_circle
                      : isVencido
                      ? Icons.error_outline
                      : Icons.radio_button_unchecked,
                  color: isCumplido
                      ? const Color(0xFF4CAF50)
                      : isVencido
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${compromiso.numero}. ${compromiso.tarea}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: isCumplido
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          compromiso.responsable,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fechaStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isVencido
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isVencido ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(status: compromiso.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CompromisoStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      CompromisoStatus.pendiente => (
        Theme.of(context).colorScheme.primary,
        'Pendiente',
      ),
      CompromisoStatus.cumplido => (const Color(0xFF4CAF50), 'Cumplido'),
      CompromisoStatus.vencido => (
        Theme.of(context).colorScheme.error,
        'Vencido',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
