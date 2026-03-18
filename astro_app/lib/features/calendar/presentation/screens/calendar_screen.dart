import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/constants/app_typography.dart';
import 'package:astro/core/models/cita.dart';
import 'package:astro/core/models/cita_status.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/citas/providers/cita_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla de Calendario global — muestra citas de todos los proyectos
/// del usuario actual. Toggle entre vista mensual y agenda.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _showCalendar = true; // true = calendario mensual, false = agenda
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Cita> _getEventsForDay(DateTime day, List<Cita> allCitas) {
    return allCitas.where((c) {
      if (c.fecha == null) return false;
      return isSameDay(c.fecha!, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final citasAsync = ref.watch(myCitasProvider);
    final allCitas = citasAsync.value ?? [];

    final myProjects = ref.watch(myProjectsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CALENDARIO',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    _ViewToggle(
                      showCalendar: _showCalendar,
                      onToggle: () =>
                          setState(() => _showCalendar = !_showCalendar),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Content ──────────────────────────────────
              Expanded(
                child: citasAsync.isLoading && allCitas.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _showCalendar
                    ? _buildCalendarView(theme, allCitas)
                    : _buildAgendaView(theme, allCitas),
              ),
            ],
          ),
        ),
        floatingActionButton: myProjects.isNotEmpty
            ? FloatingActionButton(
                heroTag: 'calendar_fab',
                onPressed: () => _showProjectPicker(context, myProjects),
                tooltip: 'Nueva cita',
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  // ── Project picker for FAB ──────────────────────────────

  void _showProjectPicker(BuildContext context, List<Proyecto> projects) {
    if (projects.length == 1) {
      context.push('/projects/${projects.first.id}/citas/new');
      return;
    }

    // Ordenar A-Z por defecto
    final sorted = [...projects]
      ..sort(
        (a, b) => a.nombreProyecto.toLowerCase().compareTo(
          b.nombreProyecto.toLowerCase(),
        ),
      );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ProjectPickerSheet(
        projects: sorted,
        onSelected: (p) {
          Navigator.pop(ctx);
          context.push('/projects/${p.id}/citas/new');
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  VISTA CALENDARIO MENSUAL
  // ══════════════════════════════════════════════════════════

  Widget _buildCalendarView(ThemeData theme, List<Cita> allCitas) {
    final selectedEvents = _getEventsForDay(
      _selectedDay ?? _focusedDay,
      allCitas,
    );

    return Column(
      children: [
        // ── Calendar grid ────────────────────────────
        TableCalendar<Cita>(
          firstDay: DateTime(2024),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) => _getEventsForDay(day, allCitas),
          startingDayOfWeek: StartingDayOfWeek.monday,
          locale: 'es_ES',
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() => _calendarFormat = format);
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: true,
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            formatButtonTextStyle: theme.textTheme.labelSmall!,
            titleTextStyle: theme.textTheme.titleMedium!.copyWith(
              fontFamily: AppTypography.fontFamilyDisplay,
              letterSpacing: 1,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: theme.colorScheme.onSurface,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: AppTypography.fontFamilyDisplay,
            ),
            weekendStyle: theme.textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontFamily: AppTypography.fontFamilyDisplay,
            ),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            todayTextStyle: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            defaultTextStyle: theme.textTheme.bodyMedium!,
            weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            markerDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerSize: 6,
            markersMaxCount: 3,
          ),
        ),

        const SizedBox(height: 8),
        Divider(color: theme.colorScheme.outlineVariant, height: 1),

        // ── Selected day events ──────────────────────
        Expanded(
          child: selectedEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sin citas este día',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) =>
                      _CitaCard(cita: selectedEvents[index], showDate: false),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  VISTA AGENDA
  // ══════════════════════════════════════════════════════════

  Widget _buildAgendaView(ThemeData theme, List<Cita> allCitas) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Agrupar citas por sección temporal
    final overdue = <Cita>[];
    final todayCitas = <Cita>[];
    final tomorrowCitas = <Cita>[];
    final thisWeekCitas = <Cita>[];
    final laterCitas = <Cita>[];
    final pastCitas = <Cita>[];

    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: 7 - today.weekday));

    for (final c in allCitas) {
      if (c.fecha == null) continue;
      final day = DateTime(c.fecha!.year, c.fecha!.month, c.fecha!.day);

      if (c.status == CitaStatus.completada ||
          c.status == CitaStatus.cancelada) {
        pastCitas.add(c);
      } else if (day.isBefore(today)) {
        overdue.add(c);
      } else if (day == today) {
        todayCitas.add(c);
      } else if (day == tomorrow) {
        tomorrowCitas.add(c);
      } else if (day.isBefore(endOfWeek) || day == endOfWeek) {
        thisWeekCitas.add(c);
      } else {
        laterCitas.add(c);
      }
    }

    final sections = <_AgendaSection>[
      if (overdue.isNotEmpty)
        _AgendaSection('VENCIDAS', overdue, AppColors.error),
      if (todayCitas.isNotEmpty)
        _AgendaSection('HOY', todayCitas, theme.colorScheme.primary),
      if (tomorrowCitas.isNotEmpty)
        _AgendaSection('MAÑANA', tomorrowCitas, AppColors.warning),
      if (thisWeekCitas.isNotEmpty)
        _AgendaSection(
          'ESTA SEMANA',
          thisWeekCitas,
          theme.colorScheme.secondary,
        ),
      if (laterCitas.isNotEmpty)
        _AgendaSection(
          'PRÓXIMAMENTE',
          laterCitas,
          theme.colorScheme.onSurfaceVariant,
        ),
      if (pastCitas.isNotEmpty)
        _AgendaSection(
          'PASADAS',
          pastCitas,
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
    ];

    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin citas programadas',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.citas.length),
      itemBuilder: (context, index) {
        int running = 0;
        for (final section in sections) {
          if (index == running) {
            // Section header
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: section.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    section.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFamily: AppTypography.fontFamilyDisplay,
                      letterSpacing: 1.5,
                      color: section.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${section.citas.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          running++; // header
          if (index < running + section.citas.length) {
            return _CitaCard(
              cita: section.citas[index - running],
              showDate: true,
            );
          }
          running += section.citas.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS PRIVADOS
// ══════════════════════════════════════════════════════════

class _AgendaSection {
  const _AgendaSection(this.label, this.citas, this.color);
  final String label;
  final List<Cita> citas;
  final Color color;
}

/// Toggle de vista: calendario ↔ agenda.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.showCalendar, required this.onToggle});

  final bool showCalendar;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton(
            icon: Icons.calendar_month,
            label: 'Mes',
            isActive: showCalendar,
            theme: theme,
            onTap: showCalendar ? null : onToggle,
            isLeft: true,
          ),
          _toggleButton(
            icon: Icons.view_agenda_outlined,
            label: 'Agenda',
            isActive: !showCalendar,
            theme: theme,
            onTap: showCalendar ? onToggle : null,
            isLeft: false,
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required ThemeData theme,
    required bool isLeft,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(7) : Radius.zero,
            right: isLeft ? Radius.zero : const Radius.circular(7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet con búsqueda para seleccionar proyecto.
class _ProjectPickerSheet extends StatefulWidget {
  const _ProjectPickerSheet({required this.projects, required this.onSelected});

  final List<Proyecto> projects;
  final ValueChanged<Proyecto> onSelected;

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _search.isEmpty
        ? widget.projects
        : widget.projects.where((p) {
            final q = _search.toLowerCase();
            return p.nombreProyecto.toLowerCase().contains(q) ||
                p.fkEmpresa.toLowerCase().contains(q);
          }).toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Selecciona un proyecto',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: AppTypography.fontFamilyDisplay,
                letterSpacing: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar proyecto...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Sin resultados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(p.nombreProyecto),
                        subtitle: Text(p.fkEmpresa),
                        onTap: () => widget.onSelected(p),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Tarjeta de cita individual.
class _CitaCard extends ConsumerWidget {
  const _CitaCard({required this.cita, this.showDate = true});

  final Cita cita;
  final bool showDate;

  Color _statusColor(CitaStatus status) {
    return switch (status) {
      CitaStatus.programada => AppColors.info,
      CitaStatus.enCurso => AppColors.warning,
      CitaStatus.completada => AppColors.success,
      CitaStatus.cancelada => AppColors.error,
    };
  }

  IconData _modalidadIcon() {
    return switch (cita.modalidad.name) {
      'videoconferencia' => Icons.videocam_outlined,
      'presencial' => Icons.place_outlined,
      'llamada' => Icons.phone_outlined,
      'hibrida' => Icons.devices_outlined,
      _ => Icons.event_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateStr = cita.fecha != null
        ? DateFormat('EEE d MMM', 'es_ES').format(cita.fecha!)
        : '—';
    final timeStr = [
      cita.horaInicio,
      cita.horaFin,
    ].where((t) => t != null && t.isNotEmpty).join(' – ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push('/projects/${cita.projectId}/citas/${cita.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Left accent ──
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: _statusColor(cita.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // ── Modalidad icon ──
              Icon(
                _modalidadIcon(),
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),

              // ── Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita.titulo,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (showDate && cita.fecha != null) ...[
                          Text(
                            dateStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              ' · ',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cita.projectName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Status badge ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(cita.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cita.status.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _statusColor(cita.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
