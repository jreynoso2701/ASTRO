import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/constants/app_breakpoints.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';

/// Pantalla de detalle de una cita.
class CitaDetailScreen extends ConsumerWidget {
  const CitaDetailScreen({
    required this.projectId,
    required this.citaId,
    super.key,
  });

  final String projectId;
  final String citaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citaAsync = ref.watch(citaByIdProvider(citaId));
    final canManage = ref.watch(canManageProjectProvider(projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CITA'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage || isRoot)
            citaAsync.whenOrNull(
                  data: (c) => c != null
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar cita',
                          onPressed: () => context.push(
                            '/projects/$projectId/citas/$citaId/edit',
                          ),
                        )
                      : null,
                ) ??
                const SizedBox.shrink(),
        ],
      ),
      body: citaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cita) {
          if (cita == null) {
            return const Center(child: Text('Cita no encontrada'));
          }

          final width = MediaQuery.sizeOf(context).width;
          final isWide = width >= AppBreakpoints.medium;

          final infoSection = _CitaInfoSection(cita: cita);
          final actionsSection = _ActionsSection(
            cita: cita,
            canManage: canManage || isRoot,
            onStatusChange: (status) => _changeStatus(ref, cita, status),
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
                    child: actionsSection,
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
                actionsSection,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeStatus(
    WidgetRef ref,
    Cita cita,
    CitaStatus newStatus,
  ) async {
    final repo = ref.read(citaRepositoryProvider);
    await repo.updateStatus(cita.id, newStatus);
  }
}

// ── Info Section ─────────────────────────────────────────

class _CitaInfoSection extends StatelessWidget {
  const _CitaInfoSection({required this.cita});

  final Cita cita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = cita.fecha != null
        ? DateFormat('dd/MM/yyyy').format(cita.fecha!)
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
                child: const Icon(Icons.event_outlined, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                cita.titulo,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
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
                  cita.folio,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _StatusBadge(status: cita.status),
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
                _InfoRow(label: 'Fecha', value: dateStr),
                _InfoRow(
                  label: 'Hora',
                  value: '${cita.horaInicio ?? '—'} – ${cita.horaFin ?? '—'}',
                ),
                _InfoRow(label: 'Modalidad', value: cita.modalidad.label),
                if (cita.urlVideoconferencia != null &&
                    cita.urlVideoconferencia!.isNotEmpty)
                  _InfoRow(label: 'URL', value: cita.urlVideoconferencia!),
                if (cita.direccion != null && cita.direccion!.isNotEmpty)
                  _InfoRow(label: 'Dirección', value: cita.direccion!),
                _InfoRow(label: 'Empresa', value: cita.empresaName),
                _InfoRow(label: 'Creado por', value: cita.createdByName),
              ],
            ),
          ),
        ),

        // Descripción
        if (cita.descripcion != null && cita.descripcion!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESCRIPCIÓN',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(cita.descripcion!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Participantes
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARTICIPANTES',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                if (cita.participantes.isEmpty)
                  Text(
                    'Sin participantes registrados',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...cita.participantes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            p.confirmado
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: p.confirmado
                                ? const Color(0xFF4CAF50)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nombre,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (p.rol != null && p.rol!.isNotEmpty)
                                  Text(
                                    p.rol!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            p.confirmado ? 'Confirmado' : 'Pendiente',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: p.confirmado
                                  ? const Color(0xFF4CAF50)
                                  : theme.colorScheme.onSurfaceVariant,
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

        // Recordatorios
        if (cita.recordatorios.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECORDATORIOS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    children: cita.recordatorios.map((mins) {
                      final label = mins >= 60
                          ? '${mins ~/ 60}h antes'
                          : '${mins}min antes';
                      return Chip(
                        label: Text(label),
                        avatar: const Icon(
                          Icons.notifications_outlined,
                          size: 16,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Notas
        if (cita.notas != null && cita.notas!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOTAS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(cita.notas!, style: theme.textTheme.bodyMedium),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CitaStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      CitaStatus.programada => (
        Theme.of(context).colorScheme.primary,
        'Programada',
      ),
      CitaStatus.enCurso => (const Color(0xFFFFA726), 'En curso'),
      CitaStatus.completada => (const Color(0xFF4CAF50), 'Completada'),
      CitaStatus.cancelada => (
        Theme.of(context).colorScheme.error,
        'Cancelada',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Actions Section ──────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.cita,
    required this.canManage,
    required this.onStatusChange,
  });

  final Cita cita;
  final bool canManage;
  final ValueChanged<CitaStatus> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!canManage) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCIONES',
          style: theme.textTheme.labelLarge?.copyWith(
            letterSpacing: 1,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),

        Text(
          'Cambiar estado:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CitaStatus.values
              .where((s) => s != cita.status)
              .map(
                (s) => OutlinedButton(
                  onPressed: () => onStatusChange(s),
                  child: Text(s.label),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
