import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/core/models/documento_seccion.dart';
import 'package:astro/core/models/documento_categoria.dart';
import 'package:astro/core/models/bitacora_documento.dart';
import 'package:astro/core/models/categoria_custom.dart';
import 'package:astro/core/models/adjunto_compartido.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/user_role.dart';
import 'package:astro/features/documentation/data/documento_repository.dart';
import 'package:astro/features/auth/providers/auth_providers.dart';
import 'package:astro/features/users/providers/user_providers.dart';
import 'package:astro/features/projects/providers/project_providers.dart';
import 'package:astro/features/tickets/providers/ticket_providers.dart';
import 'package:astro/features/requirements/providers/requerimiento_providers.dart';

// ── Repository ───────────────────────────────────────────

final documentoRepositoryProvider = Provider<DocumentoRepository>((ref) {
  return DocumentoRepository();
});

// ── Documentos formales por proyecto (por nombre) ────────

final documentosByProjectProvider =
    StreamProvider.family<List<DocumentoProyecto>, String>((ref, projectName) {
      return ref.watch(documentoRepositoryProvider).watchByProject(projectName);
    });

// ── Documento individual ─────────────────────────────────

final documentoByIdProvider = StreamProvider.family<DocumentoProyecto?, String>(
  (ref, id) {
    return ref.watch(documentoRepositoryProvider).watchDocumento(id);
  },
);

// ── Bitácora del proyecto ────────────────────────────────

final bitacoraByProjectProvider =
    StreamProvider.family<List<BitacoraDocumento>, String>((ref, projectId) {
      return ref.watch(documentoRepositoryProvider).watchBitacora(projectId);
    });

// ── Bitácora de un documento ─────────────────────────────

final bitacoraByDocProvider =
    StreamProvider.family<List<BitacoraDocumento>, String>((ref, documentId) {
      return ref
          .watch(documentoRepositoryProvider)
          .watchBitacoraByDoc(documentId);
    });

// ── Categorías personalizadas ────────────────────────────

final categoriasCustomProvider =
    StreamProvider.family<List<CategoriaCustom>, String>((ref, projectId) {
      return ref.watch(documentoRepositoryProvider).watchCategorias(projectId);
    });

/// Todas las categorías disponibles (default + custom) para un proyecto.
final allCategoriasProvider = Provider.family<List<String>, String>((
  ref,
  projectId,
) {
  final defaults = DocumentoCategoria.defaultLabels;
  final customs = ref.watch(categoriasCustomProvider(projectId)).value ?? [];
  final customNames = customs.map((c) => c.nombre).toList();
  return [...defaults, ...customNames];
});

// ── Filtros ──────────────────────────────────────────────

class DocSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final docSearchProvider = NotifierProvider<DocSearchNotifier, String>(
  DocSearchNotifier.new,
);

class DocCategoriaFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? categoria) => state = categoria;
  void clear() => state = null;
}

final docCategoriaFilterProvider =
    NotifierProvider<DocCategoriaFilterNotifier, String?>(
      DocCategoriaFilterNotifier.new,
    );

// ── Documentos formales filtrados ────────────────────────

/// Documentos formales filtrados para un proyecto.
///
/// Visibilidad:
/// - Root / Soporte → todos los documentos formales.
/// - Supervisor → solo lectura (puede ver todos).
/// - Usuario → NO tiene acceso a documentos formales.
final filteredDocumentosProvider =
    Provider.family<List<DocumentoProyecto>, String>((ref, projectId) {
      final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
      if (proyecto == null) return [];
      final projectName = proyecto.nombreProyecto;

      final isRoot = ref.watch(isCurrentUserRootProvider);
      final uid = ref.watch(authStateProvider).value?.uid;

      // Determinar el rol del usuario en este proyecto.
      final List<ProjectAssignment> assignments = uid != null
          ? (ref.watch(userAssignmentsProvider(uid)).value ?? [])
          : [];
      final projectAssignment = assignments.where(
        (a) => a.projectId == projectId && a.isActive,
      );
      final isUsuarioOnly =
          !isRoot &&
          projectAssignment.isNotEmpty &&
          projectAssignment.every((a) => a.role == UserRole.usuario);

      // Usuario no tiene acceso a documentos formales.
      if (isUsuarioOnly) return [];

      List<DocumentoProyecto> allDocs =
          ref.watch(documentosByProjectProvider(projectName)).value ?? [];

      // Filtrar solo formales.
      allDocs = allDocs
          .where((d) => d.seccion == DocumentoSeccion.formal)
          .toList();

      final query = ref.watch(docSearchProvider).toUpperCase();
      final categoriaFilter = ref.watch(docCategoriaFilterProvider);

      return allDocs.where((d) {
        if (categoriaFilter != null && d.categoria != categoriaFilter) {
          return false;
        }
        if (query.isNotEmpty) {
          final matchesQuery =
              d.titulo.toUpperCase().contains(query) ||
              d.folio.toUpperCase().contains(query) ||
              (d.descripcion?.toUpperCase().contains(query) ?? false) ||
              d.categoria.toUpperCase().contains(query);
          if (!matchesQuery) return false;
        }
        return true;
      }).toList();
    });

// ── Adjuntos compartidos (agregados de tickets + reqs) ───

/// Adjuntos compartidos de tickets y requerimientos de un proyecto.
/// Se generan en tiempo real sin almacenamiento adicional.
final adjuntosCompartidosProvider =
    Provider.family<List<AdjuntoCompartido>, String>((ref, projectId) {
      final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
      if (proyecto == null) return [];
      final projectName = proyecto.nombreProyecto;

      final adjuntos = <AdjuntoCompartido>[];

      // Agregar evidencias de tickets.
      final tickets =
          ref.watch(ticketsByProjectProvider(projectName)).value ?? [];
      for (final ticket in tickets) {
        for (final url in ticket.evidencias) {
          adjuntos.add(
            AdjuntoCompartido(
              url: url,
              origen: 'ticket',
              origenId: ticket.id,
              origenFolio: ticket.folio,
              origenTitulo: ticket.titulo,
              projectName: projectName,
              uploadedAt: ticket.updatedAt,
              autorNombre: ticket.createdByName,
              moduleName: ticket.moduleName,
              origenStatus: ticket.status.label,
              origenPrioridad: ticket.priority.label,
              createdAt: ticket.createdAt,
            ),
          );
        }
      }

      // Agregar adjuntos de requerimientos.
      final reqs =
          ref.watch(requerimientosByProjectProvider(projectName)).value ?? [];
      for (final req in reqs) {
        for (final url in req.adjuntos) {
          adjuntos.add(
            AdjuntoCompartido(
              url: url,
              origen: 'requerimiento',
              origenId: req.id,
              origenFolio: req.folio,
              origenTitulo: req.titulo,
              projectName: projectName,
              uploadedAt: req.updatedAt,
              autorNombre: req.createdByName,
              moduleName: req.moduleName ?? req.moduloPropuesto,
              origenStatus: req.status.label,
              origenPrioridad: req.prioridad.label,
              createdAt: req.createdAt,
            ),
          );
        }
      }

      // Ordenar por fecha más reciente.
      adjuntos.sort(
        (a, b) => (b.uploadedAt ?? DateTime(2000)).compareTo(
          a.uploadedAt ?? DateTime(2000),
        ),
      );

      return adjuntos;
    });

// ── Filtros y ordenamiento para Compartidos ──────────────

/// Filtro por origen: null = todos, 'ticket', 'requerimiento'.
final adjuntoOrigenFilterProvider =
    NotifierProvider<_StringFilterNotifier, String?>(_StringFilterNotifier.new);

/// Filtro por tipo de archivo: null = todos, 'imagen', 'pdf', etc.
final adjuntoTipoFilterProvider =
    NotifierProvider<_StringFilterNotifier, String?>(_StringFilterNotifier.new);

/// Ordenamiento de compartidos.
enum AdjuntoSortMode { reciente, antiguo, nombre, folio }

final adjuntoSortProvider =
    NotifierProvider<_AdjuntoSortNotifier, AdjuntoSortMode>(
      _AdjuntoSortNotifier.new,
    );

class _StringFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
  void clear() => state = null;
}

class _AdjuntoSortNotifier extends Notifier<AdjuntoSortMode> {
  @override
  AdjuntoSortMode build() => AdjuntoSortMode.reciente;
  void set(AdjuntoSortMode value) => state = value;
}

/// Adjuntos compartidos filtrados con búsqueda, filtro por origen/tipo
/// y ordenamiento.
final filteredAdjuntosProvider =
    Provider.family<List<AdjuntoCompartido>, String>((ref, projectId) {
      final allAdjuntos = ref.watch(adjuntosCompartidosProvider(projectId));
      final query = ref.watch(docSearchProvider).toUpperCase();
      final origenFilter = ref.watch(adjuntoOrigenFilterProvider);
      final tipoFilter = ref.watch(adjuntoTipoFilterProvider);
      final sortMode = ref.watch(adjuntoSortProvider);

      var result = allAdjuntos.where((a) {
        // Filtro por origen.
        if (origenFilter != null && a.origen != origenFilter) return false;
        // Filtro por tipo.
        if (tipoFilter != null && a.tipoArchivo != tipoFilter) return false;
        // Búsqueda textual.
        if (query.isNotEmpty) {
          return a.displayName.toUpperCase().contains(query) ||
              a.origenFolio.toUpperCase().contains(query) ||
              a.origenTitulo.toUpperCase().contains(query) ||
              (a.autorNombre?.toUpperCase().contains(query) ?? false) ||
              (a.moduleName?.toUpperCase().contains(query) ?? false) ||
              a.origenLabel.toUpperCase().contains(query);
        }
        return true;
      }).toList();

      // Ordenar.
      switch (sortMode) {
        case AdjuntoSortMode.reciente:
          result.sort(
            (a, b) => (b.uploadedAt ?? DateTime(2000)).compareTo(
              a.uploadedAt ?? DateTime(2000),
            ),
          );
        case AdjuntoSortMode.antiguo:
          result.sort(
            (a, b) => (a.uploadedAt ?? DateTime(2000)).compareTo(
              b.uploadedAt ?? DateTime(2000),
            ),
          );
        case AdjuntoSortMode.nombre:
          result.sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
        case AdjuntoSortMode.folio:
          result.sort((a, b) => a.origenFolio.compareTo(b.origenFolio));
      }

      return result;
    });

// ── Contadores rápidos ───────────────────────────────────

/// Cuenta total de documentos formales de un proyecto.
final formalDocCountProvider = Provider.family<int, String>((ref, projectId) {
  final proyecto = ref.watch(proyectoByIdProvider(projectId)).value;
  if (proyecto == null) return 0;
  final docs =
      ref.watch(documentosByProjectProvider(proyecto.nombreProyecto)).value ??
      [];
  return docs.where((d) => d.seccion == DocumentoSeccion.formal).length;
});

// ── Helper: puede gestionar documentos formales ──────────

/// Determina si el usuario actual puede gestionar (subir/editar) documentos
/// formales en un proyecto dado.
/// Solo Root y Soporte pueden gestionar.
final canManageDocumentsProvider = Provider.family<bool, String>((
  ref,
  projectId,
) {
  final isRoot = ref.watch(isCurrentUserRootProvider);
  if (isRoot) return true;

  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return false;

  final assignments = ref.watch(userAssignmentsProvider(uid)).value ?? [];
  return assignments.any(
    (a) => a.projectId == projectId && a.isActive && a.role == UserRole.soporte,
  );
});
