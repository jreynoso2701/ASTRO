import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/core/models/ticket.dart';
import 'package:astro/core/utils/ticket_colors.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';

void showDashboardTicketSearchSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) =>
          _DashboardTicketSearchSheet(scrollController: scrollController),
    ),
  );
}

class _DashboardTicketSearchSheet extends ConsumerStatefulWidget {
  const _DashboardTicketSearchSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_DashboardTicketSearchSheet> createState() =>
      _DashboardTicketSearchSheetState();
}

class _DashboardTicketSearchSheetState
    extends ConsumerState<_DashboardTicketSearchSheet> {
  final _controller = TextEditingController();
  late final DashboardTicketSearchNotifier _searchNotifier;

  @override
  void initState() {
    super.initState();
    // Guardamos la referencia en initState para poder usarla en dispose(),
    // ya que ref no está disponible cuando el widget está desmontándose.
    _searchNotifier = ref.read(dashboardTicketSearchProvider.notifier);
  }

  @override
  void dispose() {
    // Diferir la modificación del provider para evitar modificar el árbol
    // durante el desmontaje (dispose ocurre mientras el árbol se reconstruye).
    Future.microtask(_searchNotifier.clear);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text;
    final results = ref.watch(globalTicketSearchResultsProvider);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Column(
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header + search field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.search, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Buscar por folio, título o descripción…',
                      border: InputBorder.none,
                      isDense: true,
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _controller.clear();
                                ref
                                    .read(
                                      dashboardTicketSearchProvider.notifier,
                                    )
                                    .clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      ref
                          .read(dashboardTicketSearchProvider.notifier)
                          .setQuery(v);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Results ──
          Expanded(
            child: query.isEmpty
                ? _EmptyQueryHint(theme: theme)
                : results.isEmpty
                ? _NoResultsView(query: query, theme: theme)
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: results.length,
                    itemBuilder: (ctx, i) => _TicketSearchResultTile(
                      entry: results[i],
                      onTap: () {
                        Navigator.pop(ctx);
                        final t = results[i].ticket;
                        final pid =
                            t.projectId ?? results[i].project.id;
                        ctx.push('/projects/$pid/tickets/${t.id}');
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyQueryHint extends StatelessWidget {
  const _EmptyQueryHint({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'Escribe para buscar tickets\nen todos tus proyectos',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView({required this.query, required this.theme});
  final String query;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 56,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin resultados para',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Text(
            '"$query"',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketSearchResultTile extends StatelessWidget {
  const _TicketSearchResultTile({
    required this.entry,
    required this.onTap,
  });

  final ({Proyecto project, Ticket ticket}) entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = entry.ticket;
    final p = entry.project;
    final theme = Theme.of(context);
    final prioColor = ticketPriorityColor(t.priority);

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: prioColor,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        t.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${t.folio} · ${p.nombreProyecto} · ${t.status.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }

}
