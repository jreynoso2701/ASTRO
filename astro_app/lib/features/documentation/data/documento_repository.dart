import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/documento_proyecto.dart';
import 'package:astro/core/models/documento_version.dart';
import 'package:astro/core/models/bitacora_documento.dart';
import 'package:astro/core/models/categoria_custom.dart';

/// Repositorio CRUD de documentos formales del proyecto.
///
/// Colección: `DocumentosProyecto/{docId}`.
/// Bitácora: `BitacoraDocumentos/{logId}`.
/// Categorías: `CategoriasDocumento/{catId}`.
class DocumentoRepository {
  DocumentoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('DocumentosProyecto');

  CollectionReference<Map<String, dynamic>> get _bitacoraRef =>
      _firestore.collection('BitacoraDocumentos');

  CollectionReference<Map<String, dynamic>> get _categoriasRef =>
      _firestore.collection('CategoriasDocumento');

  // ── Documentos ─────────────────────────────────────────

  /// Stream de documentos formales activos de un proyecto.
  Stream<List<DocumentoProyecto>> watchByProject(String projectName) {
    return _ref
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(DocumentoProyecto.fromFirestore).toList();
          list.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de un documento individual.
  Stream<DocumentoProyecto?> watchDocumento(String id) {
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return DocumentoProyecto.fromFirestore(doc);
    });
  }

  /// Genera folio: EMPRESA-PROYECTO-DOC-NUM.
  Future<String> _nextFolio(String projectName, [String? empresaName]) async {
    final snap = await _ref.where('projectName', isEqualTo: projectName).get();

    int maxNum = 0;
    for (final doc in snap.docs) {
      final folio = doc.data()['folio'] as String? ?? '';
      final parts = folio.split('-');
      if (parts.isNotEmpty) {
        final num = int.tryParse(parts.last) ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }

    final empAbbr = _abbreviate(empresaName ?? '');
    final projAbbr = _abbreviate(projectName);
    final prefix = empAbbr.isNotEmpty
        ? '$empAbbr-$projAbbr-DOC'
        : '$projAbbr-DOC';
    return '$prefix-${maxNum + 1}';
  }

  static String _abbreviate(String name) {
    if (name.isEmpty) return '';
    final firstWord = name.trim().split(RegExp(r'\s+')).first;
    return firstWord.substring(0, min(3, firstWord.length)).toUpperCase();
  }

  /// Crea un nuevo documento formal.
  Future<String> create(DocumentoProyecto documento) async {
    final folio = await _nextFolio(
      documento.projectName,
      documento.empresaName,
    );

    final data = documento.toFirestore();
    data['folio'] = folio;
    data['createdAt'] = Timestamp.fromDate(DateTime.now());

    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza un documento (merge).
  Future<void> update(DocumentoProyecto documento) async {
    await _ref
        .doc(documento.id)
        .set(documento.toFirestore(), SetOptions(merge: true));
  }

  /// Sube una nueva versión del documento.
  Future<void> addVersion(
    String docId,
    DocumentoVersion version,
    String newUrl,
    String newNombre,
    String? newTipo,
    int? newSize,
  ) async {
    await _ref.doc(docId).update({
      'versiones': FieldValue.arrayUnion([version.toMap()]),
      'versionActual': version.version,
      'archivoUrl': newUrl,
      'archivoNombre': newNombre,
      if (newTipo != null) 'archivoTipo': newTipo,
      if (newSize != null) 'archivoSize': newSize,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Soft delete.
  Future<void> deactivate(String id) async {
    await _ref.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Reactivar.
  Future<void> activate(String id) async {
    await _ref.doc(id).update({
      'isActive': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Bitácora ───────────────────────────────────────────

  /// Stream de bitácora de documentos de un proyecto.
  Stream<List<BitacoraDocumento>> watchBitacora(String projectId) {
    return _bitacoraRef
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BitacoraDocumento.fromFirestore).toList());
  }

  /// Stream de bitácora de un documento específico.
  Stream<List<BitacoraDocumento>> watchBitacoraByDoc(String documentId) {
    return _bitacoraRef
        .where('documentId', isEqualTo: documentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(BitacoraDocumento.fromFirestore).toList());
  }

  /// Registra una entrada en la bitácora.
  Future<void> logBitacora(BitacoraDocumento entry) async {
    await _bitacoraRef.add(entry.toFirestore());
  }

  // ── Categorías Personalizadas ──────────────────────────

  /// Stream de categorías personalizadas de un proyecto.
  Stream<List<CategoriaCustom>> watchCategorias(String projectId) {
    return _categoriasRef
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(CategoriaCustom.fromFirestore).toList());
  }

  /// Crea una categoría personalizada.
  Future<String> createCategoria(CategoriaCustom categoria) async {
    final doc = await _categoriasRef.add(categoria.toFirestore());
    return doc.id;
  }

  /// Desactiva una categoría personalizada.
  Future<void> deactivateCategoria(String id) async {
    await _categoriasRef.doc(id).update({'isActive': false});
  }
}
