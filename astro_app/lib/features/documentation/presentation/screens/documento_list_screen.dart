import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/core/models/adjunto_compartido.dart';
import 'package:astro/features/documentation/providers/documento_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/core/presentation/screens/file_viewer_screen.dart';
import 'package:intl/intl.dart';
import 'package:astro/core/widgets/adaptive_body.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_filter_button.dart';

/// Pantalla de documentación de un proyecto con dos tabs:
/// - Formales: documentos gestionados (memorias, contratos, etc.)
/// - Compartidos: adjuntos de tickets y requerimientos (auto-agregados)
class DocumentoListScreen extends ConsumerWidget {
  const DocumentoListScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proyectoAsync = ref.watch(proyectoByIdProvider(projectId));

    return proyectoAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('DOCUMENTACIÓN')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('DOCUMENTACIÓN')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (proyecto) {
        if (proyecto == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('DOCUMENTACIÓN')),
            body: const Center(child: Text('Proyecto no encontrado')),
          );
        }

        return _DocumentoListBody(
          projectId: projectId,
          projectName: proyecto.nombreProyecto,
        );
      },
    );
  }
}

class _DocumentoListBody extends ConsumerStatefulWidget {
  const _DocumentoListBody({
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  ConsumerState<_DocumentoListBody> createState() => _DocumentoListBodyState();
}

class _DocumentoListBodyState extends ConsumerState<_DocumentoListBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageDocumentsProvider(widget.projectId));
    final isRoot = ref.watch(isCurrentUserRootProvider);
    final searchQuery = ref.watch(docSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('DOCUMENTACIÓN — ${widget.projectName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nuevo documento',
              onPressed: () =>
                  context.push('/projects/${widget.projectId}/documents/new'),
            ),
          if (isRoot)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'bitacora') {
                  context.push('/projects/${widget.projectId}/documents/log');
                } else if (value == 'categorias') {
                  context.push(
                    '/projects/${widget.projectId}/documents/categories',
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'bitacora',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Bitácora'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'categorias',
                  child: ListTile(
                    leading: Icon(Icons.category),
                    title: Text('Categorías'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'FORMALES'),
            Tab(text: 'COMPARTIDOS'),
            Tab(text: 'COMPARTIDOS CONMIGO'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar documento...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              ref.read(docSearchProvider.notifier).clear(),
                        )
                      : null,
                  isDense: true,
                ),
                onChanged: (v) =>
                    ref.read(docSearchProvider.notifier).setQuery(v),
              ),
            ),

            // Tabs content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FormalesTab(projectId: widget.projectId),
                  _CompartidosTab(projectId: widget.projectId),
                  _SharedWithMeTab(projectId: widget.projectId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Formales ─────────────────────────────────────────

class _FormalesTab extends ConsumerWidget {
  const _FormalesTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filteredDocs = ref.watch(filteredDocumentosProvider(projectId));
    final categoriaFilter = ref.watch(docCategoriaFilterProvider);
    final allCategorias = ref.watch(allCategoriasProvider(projectId));
    final etiquetaFilter = ref.watch(docEtiquetaFilterProvider);
    final availableEtiquetas =
        ref.watch(availableEtiquetasProvider(projectId)).value ?? [];

    return AdaptiveBody(
      maxWidth: 960,
      child: Column(
        children: [
          // Filtro de categoría
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'Todas',
                  selected: categoriaFilter == null,
                  onSelected: (_) =>
                      ref.read(docCategoriaFilterProvider.notifier).clear(),
                ),
                for (final cat in allCategorias)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _FilterChip(
                      label: cat,
                      selected: categoriaFilter == cat,
                      onSelected: (_) => ref
                          .read(docCategoriaFilterProvider.notifier)
                          .set(cat),
                    ),
                  ),
              ],
            ),
          ),

          // Contador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filteredDocs.length} documento${filteredDocs.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (availableEtiquetas.isNotEmpty)
                  EtiquetaFilterButton(
                    etiquetas: availableEtiquetas,
                    selectedIds: etiquetaFilter,
                    onToggle: (id) =>
                        ref.read(docEtiquetaFilterProvider.notifier).toggle(id),
                    onClear: () =>
                        ref.read(docEtiquetaFilterProvider.notifier).clear(),
                  ),
              ],
            ),
          ),

          // Lista
          Expanded(
            child: filteredDocs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sin documentos formales',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      return _DocumentCard(
                        documento: doc,
                        onTap: () => context.push(
                          '/projects/$projectId/documents/${doc.id}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Compartidos ──────────────────────────────────────

class _CompartidosTab extends ConsumerWidget {
  const _CompartidosTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final adjuntos = ref.watch(filteredAdjuntosProvider(projectId));
    final origenFilter = ref.watch(adjuntoOrigenFilterProvider);
    final tipoFilter = ref.watch(adjuntoTipoFilterProvider);
    final sortMode = ref.watch(adjuntoSortProvider);

    return AdaptiveBody(
      maxWidth: 960,
      child: Column(
        children: [
          // ── Filtros ──────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // Origen
                _FilterChip(
                  label: 'Todos',
                  selected: origenFilter == null,
                  onSelected: (_) =>
                      ref.read(adjuntoOrigenFilterProvider.notifier).clear(),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Tickets',
                  selected: origenFilter == 'ticket',
                  onSelected: (_) => ref
                      .read(adjuntoOrigenFilterProvider.notifier)
                      .set(origenFilter == 'ticket' ? null : 'ticket'),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'Requerimientos',
                  selected: origenFilter == 'requerimiento',
                  onSelected: (_) => ref
                      .read(adjuntoOrigenFilterProvider.notifier)
                      .set(
                        origenFilter == 'requerimiento'
                            ? null
                            : 'requerimiento',
                      ),
                ),
                const SizedBox(width: 12),
                // Separador vertical.
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 12),
                // Tipo de archivo
                for (final tipo in const [
                  'imagen',
                  'pdf',
                  'video',
                  'word',
                  'excel',
                ]) ...[
                  _FilterChip(
                    label: _tipoLabel(tipo),
                    selected: tipoFilter == tipo,
                    onSelected: (_) => ref
                        .read(adjuntoTipoFilterProvider.notifier)
                        .set(tipoFilter == tipo ? null : tipo),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

          // ── Contador + ordenamiento ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${adjuntos.length} archivo${adjuntos.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                PopupMenuButton<AdjuntoSortMode>(
                  tooltip: 'Ordenar',
                  icon: Icon(
                    Icons.sort,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (mode) =>
                      ref.read(adjuntoSortProvider.notifier).set(mode),
                  itemBuilder: (_) => [
                    for (final mode in AdjuntoSortMode.values)
                      PopupMenuItem(
                        value: mode,
                        child: Row(
                          children: [
                            if (sortMode == mode)
                              const Icon(Icons.check, size: 18)
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text(_sortLabel(mode)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Lista ────────────────────────────────────────
          Expanded(
            child: adjuntos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sin archivos compartidos',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Los adjuntos de tickets y requerimientos\naparecerán aquí automáticamente',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: adjuntos.length,
                    itemBuilder: (context, index) {
                      final adjunto = adjuntos[index];
                      return _AdjuntoCard(adjunto: adjunto);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _tipoLabel(String tipo) {
    return switch (tipo) {
      'imagen' => 'Imágenes',
      'video' => 'Videos',
      'pdf' => 'PDFs',
      'word' => 'Word',
      'excel' => 'Excel',
      _ => tipo,
    };
  }

  static String _sortLabel(AdjuntoSortMode mode) {
    return switch (mode) {
      AdjuntoSortMode.reciente => 'Más recientes',
      AdjuntoSortMode.antiguo => 'Más antiguos',
      AdjuntoSortMode.nombre => 'Nombre A–Z',
      AdjuntoSortMode.folio => 'Folio',
    };
  }
}

// ── Document Card ────────────────────────────────────────

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.documento, required this.onTap});

  final DocumentoProyecto documento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: folio + categoría badge
              Row(
                children: [
                  Text(
                    documento.folio,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      documento.categoria,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Título
              Text(
                documento.titulo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (documento.descripcion != null &&
                  documento.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  documento.descripcion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const Divider(height: 16),

              // Info row
              Row(
                children: [
                  Icon(
                    _fileIcon(documento.archivoTipo),
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      documento.archivoNombre ?? 'Sin archivo',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.layers_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'v${documento.versionActual}',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      documento.createdByName,
                      style: theme.textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Etiquetas
              if (documento.etiquetaIds.isNotEmpty)
                Builder(
                  builder: (_) {
                    final idsKey = documento.etiquetaIds.join(',');
                    final etiquetas =
                        ref.watch(etiquetasByIdsProvider(idsKey)).value ?? [];
                    if (etiquetas.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: EtiquetasRow(
                        etiquetas: etiquetas,
                        compact: true,
                        maxVisible: 3,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _fileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('image')) return Icons.image_outlined;
    if (mimeType.contains('video')) return Icons.videocam_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description_outlined;
    }
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

// ── Adjunto Compartido Card ──────────────────────────────

class _AdjuntoCard extends StatelessWidget {
  const _AdjuntoCard({required this.adjunto});

  final AdjuntoCompartido adjunto;

  static const _accent = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tipoColor = _tipoColor(adjunto.tipoArchivo);
    final dateStr = adjunto.createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'es').format(adjunto.createdAt!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => FileViewerScreen.open(
          context,
          url: adjunto.url,
          fileName: adjunto.displayName,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila principal: icono + nombre + badge ──
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tipoColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _tipoIcon(adjunto.tipoArchivo),
                      color: tipoColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adjunto.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dateStr != null)
                          Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Badge origen
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (adjunto.origen == 'ticket'
                                  ? Colors.orange
                                  : Colors.teal)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          adjunto.origen == 'ticket'
                              ? Icons.confirmation_num_outlined
                              : Icons.assignment_outlined,
                          size: 13,
                          color: adjunto.origen == 'ticket'
                              ? Colors.orange
                              : Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          adjunto.origenLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: adjunto.origen == 'ticket'
                                ? Colors.orange
                                : Colors.teal,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Folio + Título del origen ──
              Row(
                children: [
                  Text(
                    adjunto.origenFolio,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      adjunto.origenTitulo,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ── Metadatos: autor, módulo, status, prioridad ──
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (adjunto.autorNombre != null)
                    _MetaChip(
                      icon: Icons.person_outline,
                      label: adjunto.autorNombre!,
                    ),
                  if (adjunto.moduleName != null)
                    _MetaChip(
                      icon: Icons.extension_outlined,
                      label: adjunto.moduleName!,
                    ),
                  if (adjunto.origenStatus != null)
                    _MetaChip(
                      icon: Icons.circle,
                      iconSize: 8,
                      label: adjunto.origenStatus!,
                    ),
                  if (adjunto.origenPrioridad != null)
                    _MetaChip(
                      icon: Icons.flag_outlined,
                      label: adjunto.origenPrioridad!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _tipoIcon(String tipo) {
    return switch (tipo) {
      'imagen' => Icons.image_outlined,
      'video' => Icons.videocam_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'word' => Icons.description_outlined,
      'excel' => Icons.table_chart_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  static Color _tipoColor(String tipo) {
    return switch (tipo) {
      'imagen' => Colors.blue,
      'video' => Colors.purple,
      'pdf' => Colors.red,
      'word' => Colors.indigo,
      'excel' => Colors.green,
      _ => Colors.grey,
    };
  }
}

// ── Meta chip para metadatos compactos ───────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.iconSize = 13,
  });

  final IconData icon;
  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Tab Compartidos Conmigo (recibidos de otros proyectos) ───

class _SharedWithMeTab extends ConsumerWidget {
  const _SharedWithMeTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final docs = ref.watch(filteredSharedWithMeProvider(projectId));

    return AdaptiveBody(
      maxWidth: 960,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.share_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${docs.length} documento${docs.length == 1 ? '' : 's'} recibido${docs.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_shared_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sin documentos compartidos contigo',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Cuando un Root o Líder de proyecto comparta un documento de otro proyecto en el que también participes, aparecerá aquí.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return _SharedDocumentCard(
                        documento: doc,
                        currentProjectId: projectId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SharedDocumentCard extends ConsumerWidget {
  const _SharedDocumentCard({
    required this.documento,
    required this.currentProjectId,
  });

  final DocumentoProyecto documento;
  final String currentProjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Abrir directamente el archivo en el visor (solo lectura).
          final url = documento.archivoUrl;
          if (url == null || url.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Este documento no tiene archivo')),
            );
            return;
          }
          FileViewerScreen.open(
            context,
            url: url,
            fileName: documento.archivoNombre,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    documento.folio,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.share_outlined,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'COMPARTIDO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                documento.titulo,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (documento.descripcion != null &&
                  documento.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  documento.descripcion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Divider(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Origen: ${documento.projectName}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      documento.categoria,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              if (documento.sharedByName != null) ...[
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
                        'Compartido por ${documento.sharedByName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  static const _accent = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: _accent.withValues(alpha: 0.12),
      checkmarkColor: _accent,
      side: selected ? BorderSide(color: _accent.withValues(alpha: 0.3)) : null,
      labelStyle: TextStyle(fontSize: 12, color: selected ? _accent : null),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
