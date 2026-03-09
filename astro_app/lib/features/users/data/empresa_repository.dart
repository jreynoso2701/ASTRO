import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/empresa.dart';

/// Repositorio de lectura de Empresas existentes en Firestore.
class EmpresaRepository {
  EmpresaRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('Empresas');

  /// Obtiene todas las empresas activas.
  Future<List<Empresa>> getActiveEmpresas() async {
    final snapshot = await _ref.where('isActive', isEqualTo: true).get();
    return snapshot.docs.map(Empresa.fromFirestore).toList();
  }

  /// Stream de todas las empresas activas.
  Stream<List<Empresa>> watchActiveEmpresas() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Empresa.fromFirestore).toList());
  }

  /// Obtiene una empresa por ID.
  Future<Empresa?> getEmpresa(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Empresa.fromFirestore(doc);
  }
}
