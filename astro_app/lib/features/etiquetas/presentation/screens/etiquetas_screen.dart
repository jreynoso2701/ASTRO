import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/etiqueta.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/screens/etiqueta_form_screen.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';

/// Pantalla de gestión de etiquetas.
///
/// - Sin [projectId]: muestra solo etiquetas globales (solo Root).
/// - Con [projectId]: muestra tabs Globales + Del Proyecto, con opción de importar.
class EtiquetasScreen extends ConsumerStatefulWidget {
  const EtiquetasScreen({this.projectId, super.key});

  final String? projectId;

  @override
  ConsumerState<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends ConsumerState<EtiquetasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool get _hasProject => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _hasProject ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManageGlobal = ref.watch(canManageGlobalEtiquetasProvider);
    final canManageProject = _hasProject
        ? ref.watch(canManageProjectEtiquetasProvider(widget.projectId!))
        : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ETIQUETAS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: _hasProject
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'GLOBALES'),
                  Tab(text: 'DEL PROYECTO'),
                ],
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
            onPressed: () {
              showSearch(
                context: context,
                delegate: _EtiquetaSearchDelegate(
                  projectId: widget.projectId,
                  ref: ref,
                ),
              );
            },
          ),
          if (canManageGlobal && !_hasProject)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nueva etiqueta global',
              onPressed: () => _openForm(context),
            ),
          if (_hasProject && canManageProject)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nueva etiqueta de proyecto',
              onPressed: () => _openProjectForm(context),
            ),
        ],
      ),
      body: _hasProject
          ? TabBarView(
              controller: _tabController,
              children: [
                _GlobalTab(
                  canManage: canManageGlobal,
                  projectId: widget.projectId,
                  onImport: canManageProject ? _importGlobal : null,
                ),
                _ProjectTab(
                  projectId: widget.projectId!,
                  canManage: canManageProject,
                ),
              ],
            )
          : _GlobalTab(canManage: canManageGlobal),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EtiquetaFormScreen()));
  }

  Future<void> _openProjectForm(BuildContext context) async {
    final project = _hasProject
        ? ref.read(proyectoByIdProvider(widget.projectId!)).value
        : null;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EtiquetaFormScreen(
          projectId: widget.projectId,
          projectName: project?.nombreProyecto,
        ),
      ),
    );
  }

  Future<void> _importGlobal(BuildContext context, Etiqueta global) async {
    final project = ref.read(proyectoByIdProvider(widget.projectId!)).value;
    final authUser = ref.read(authStateProvider).value;
    final profile = ref.read(currentUserProfileProvider).value;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar etiqueta'),
        content: Text(
          '¿Deseas importar la etiqueta global "${global.nombre}" como copia en este proyecto? '
          'Podrás editarla de forma independiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(etiquetaRepositoryProvider)
            .importGlobal(
              global: global,
              projectId: widget.projectId!,
              projectName: project?.nombreProyecto ?? '',
              byUid: authUser?.uid ?? '',
              byName: profile?.displayName ?? authUser?.email ?? '',
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Etiqueta "${global.nombre}" importada al proyecto',
              ),
            ),
          );
          _tabController.animateTo(1);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al importar: $e')));
        }
      }
    }
  }
}

// ── Tab de Globales ──────────────────────────────────────

class _GlobalTab extends ConsumerWidget {
  const _GlobalTab({this.canManage = false, this.projectId, this.onImport});

  final bool canManage;
  final String? projectId;
  final Future<void> Function(BuildContext, Etiqueta)? onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etiquetasAsync = ref.watch(globalEtiquetasProvider);

    return etiquetasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (etiquetas) {
        if (etiquetas.isEmpty) {
          return const _EmptyState(
            icon: Icons.public_off,
            message: 'No hay etiquetas globales',
            sub:
                'Crea una etiqueta global para que esté disponible en todos los proyectos.',
          );
        }
        return _EtiquetaList(
          etiquetas: etiquetas,
          canManage: canManage,
          showImport: onImport != null,
          onImport: onImport != null ? (e) => onImport!(context, e) : null,
        );
      },
    );
  }
}

// ── Tab de Proyecto ──────────────────────────────────────

class _ProjectTab extends ConsumerWidget {
  const _ProjectTab({required this.projectId, this.canManage = false});

  final String projectId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etiquetasAsync = ref.watch(projectEtiquetasProvider(projectId));

    return etiquetasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (etiquetas) {
        if (etiquetas.isEmpty) {
          return const _EmptyState(
            icon: Icons.label_off,
            message: 'Sin etiquetas de proyecto',
            sub:
                'Crea etiquetas específicas para este proyecto o importa desde las globales.',
          );
        }
        return _EtiquetaList(etiquetas: etiquetas, canManage: canManage);
      },
    );
  }
}

// ── Lista de Etiquetas ───────────────────────────────────

class _EtiquetaList extends ConsumerWidget {
  const _EtiquetaList({
    required this.etiquetas,
    required this.canManage,
    this.showImport = false,
    this.onImport,
  });

  final List<Etiqueta> etiquetas;
  final bool canManage;
  final bool showImport;
  final Future<void> Function(Etiqueta)? onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: etiquetas.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) {
        final e = etiquetas[i];
        return _EtiquetaListTile(
          etiqueta: e,
          canManage: canManage,
          showImport: showImport,
          onImport: onImport != null ? () => onImport!(e) : null,
        );
      },
    );
  }
}

class _EtiquetaListTile extends ConsumerWidget {
  const _EtiquetaListTile({
    required this.etiqueta,
    required this.canManage,
    this.showImport = false,
    this.onImport,
  });

  final Etiqueta etiqueta;
  final bool canManage;
  final bool showImport;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = etiqueta.color;
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _iconForName(etiqueta.icono) != null
            ? Icon(
                _iconForName(etiqueta.icono)!,
                size: 18,
                color: color.computeLuminance() > 0.4
                    ? Colors.black87
                    : Colors.white,
              )
            : null,
      ),
      title: Text(
        etiqueta.nombre,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        etiqueta.esGlobal ? 'Global' : 'Del proyecto',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showImport)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Importar al proyecto',
              onPressed: onImport,
              iconSize: 20,
            ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              iconSize: 20,
              onPressed: () => _edit(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Desactivar',
              iconSize: 20,
              color: theme.colorScheme.error,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EtiquetaFormScreen(etiqueta: etiqueta)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar etiqueta'),
        content: Text(
          '¿Seguro que deseas desactivar "${etiqueta.nombre}"? '
          'Dejará de aparecer disponible para nuevas asignaciones, '
          'pero los items que ya la tienen no se ven afectados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(etiquetaRepositoryProvider).deactivate(etiqueta.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${etiqueta.nombre}" desactivada')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  IconData? _iconForName(String? name) {
    if (name == null) return null;
    const map = <String, IconData>{
      'label': Icons.label,
      'bug_report': Icons.bug_report,
      'code': Icons.code,
      'design_services': Icons.design_services,
      'storage': Icons.storage,
      'cloud': Icons.cloud,
      'phone_android': Icons.phone_android,
      'web': Icons.web,
      'security': Icons.security,
      'speed': Icons.speed,
      'build': Icons.build,
      'star': Icons.star,
      'priority_high': Icons.priority_high,
      'flag': Icons.flag,
      'bookmark': Icons.bookmark,
      'tag': Icons.tag,
      'work': Icons.work,
      'school': Icons.school,
      'science': Icons.science,
      'auto_awesome': Icons.auto_awesome,
    };
    return map[name];
  }
}

// ── Empty State ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  final IconData icon;
  final String message;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search delegate ──────────────────────────────────────

class _EtiquetaSearchDelegate extends SearchDelegate<void> {
  _EtiquetaSearchDelegate({this.projectId, required this.ref});

  final String? projectId;
  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Buscar etiqueta…';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final stream = projectId != null
        ? ref.watch(availableEtiquetasProvider(projectId!))
        : ref.watch(globalEtiquetasProvider);

    return stream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (etiquetas) {
        final filtered = etiquetas
            .where(
              (e) =>
                  query.isEmpty ||
                  e.nombre.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('Sin resultados'));
        }
        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = filtered[i];
            final color = e.color;
            return ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              title: Text(e.nombre),
              subtitle: Text(e.esGlobal ? 'Global' : 'Proyecto'),
            );
          },
        );
      },
    );
  }
}
