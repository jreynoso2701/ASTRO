import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/requerimiento.dart';
import 'package:astro/core/models/requerimiento_status.dart';
import 'package:astro/core/models/requerimiento_comment.dart';

/// Repositorio CRUD de Requerimientos en Firestore.
///
/// Colección: `Requerimientos/{docId}`.
/// Comentarios: `ComentariosRequerimientos/{docId}`.
class RequerimientoRepository {
  RequerimientoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Requerimientos');

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _firestore.collection('ComentariosRequerimientos');

  // ── Requerimientos ─────────────────────────────────────

  /// Stream de requerimientos activos de un proyecto (por nombre).
  Stream<List<Requerimiento>> watchByProject(String projectName) {
    return _ref
        .where('projectName', isEqualTo: projectName)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Requerimiento.fromFirestore).toList();
          list.sort(
            (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  /// Stream de un requerimiento individual.
  Stream<Requerimiento?> watchRequerimiento(String id) {
    return _ref.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Requerimiento.fromFirestore(doc);
    });
  }

  /// Genera folio: EMPRESA-PROYECTO-MOD-NUM (o EMPRESA-PROYECTO-PROP-NUM).
  Future<String> _nextFolio(
    String projectName, [
    String? moduleName,
    String? empresaName,
    String? moduloPropuesto,
  ]) async {
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
    final modAbbr = moduleName != null && moduleName.isNotEmpty
        ? _abbreviate(moduleName)
        : (moduloPropuesto != null && moduloPropuesto.isNotEmpty
              ? _abbreviate(moduloPropuesto)
              : 'GEN');

    final prefix = empAbbr.isNotEmpty
        ? '$empAbbr-$projAbbr-$modAbbr'
        : '$projAbbr-$modAbbr';
    return '$prefix-${maxNum + 1}';
  }

  static String _abbreviate(String name) {
    if (name.isEmpty) return '';
    final firstWord = name.trim().split(RegExp(r'\s+')).first;
    return firstWord.substring(0, min(3, firstWord.length)).toUpperCase();
  }

  /// Crea un nuevo requerimiento.
  Future<String> create(Requerimiento req) async {
    final folio = await _nextFolio(
      req.projectName,
      req.moduleName,
      req.empresaName,
      req.moduloPropuesto,
    );

    final data = req.toFirestore();
    data['folio'] = folio;
    data['createdAt'] = Timestamp.fromDate(DateTime.now());

    final doc = await _ref.add(data);
    return doc.id;
  }

  /// Actualiza un requerimiento (merge).
  Future<void> update(Requerimiento req) async {
    await _ref.doc(req.id).set(req.toFirestore(), SetOptions(merge: true));
  }

  /// Añade una referencia de minuta a un requerimiento.
  Future<void> addRefMinuta(String reqId, String minutaId) async {
    await _ref.doc(reqId).update({
      'refMinutas': FieldValue.arrayUnion([minutaId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Actualiza el estado.
  Future<void> updateStatus(String id, RequerimientoStatus newStatus) async {
    await _ref.doc(id).update({
      'status': newStatus.label,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Actualiza criterios de aceptación.
  Future<void> updateCriterios(
    String id,
    List<CriterioAceptacion> criterios,
  ) async {
    final completados = criterios.where((c) => c.completado).length;
    final autoPercent = criterios.isEmpty
        ? 0.0
        : (completados / criterios.length) * 100;

    // Leer si es manual
    final doc = await _ref.doc(id).get();
    final isManual = doc.data()?['porcentajeManual'] as bool? ?? false;

    final updates = <String, dynamic>{
      'criteriosAceptacion': criterios.map((c) => c.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (!isManual) {
      updates['porcentajeAvance'] = autoPercent;
    }
    await _ref.doc(id).update(updates);
  }

  /// Actualiza porcentaje manualmente.
  Future<void> updatePorcentaje(String id, double porcentaje) async {
    await _ref.doc(id).update({
      'porcentajeAvance': porcentaje,
      'porcentajeManual': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Revertir a auto-cálculo de porcentaje.
  Future<void> resetPorcentajeToAuto(String id) async {
    final doc = await _ref.doc(id).get();
    final data = doc.data() ?? {};
    final criterios = (data['criteriosAceptacion'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CriterioAceptacion.fromMap)
        .toList();
    final completados = criterios.where((c) => c.completado).length;
    final autoPercent = criterios.isEmpty
        ? 0.0
        : (completados / criterios.length) * 100;

    await _ref.doc(id).update({
      'porcentajeAvance': autoPercent,
      'porcentajeManual': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Adjuntar archivos (URLs).
  Future<void> addAdjuntos(String id, List<String> urls) async {
    await _ref.doc(id).update({
      'adjuntos': FieldValue.arrayUnion(urls),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Asignar responsable.
  Future<void> assign(
    String id,
    String assignedTo,
    String assignedToName,
  ) async {
    await _ref.doc(id).update({
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
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

  // ── Comentarios ────────────────────────────────────────

  /// Stream de comentarios de un requerimiento.
  Stream<List<RequerimientoComment>> watchComments(String reqId) {
    return _commentsRef
        .where('refRequerimiento', isEqualTo: reqId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map(RequerimientoComment.fromFirestore).toList(),
        );
  }

  /// Agrega un comentario al requerimiento.
  Future<void> addComment(String reqId, RequerimientoComment comment) async {
    final data = comment.toFirestore();
    data['refRequerimiento'] = reqId;
    await _commentsRef.add(data);
  }
}
