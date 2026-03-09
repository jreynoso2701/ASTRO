import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/project_assignment.dart';
import 'package:astro/core/models/user_role.dart';

/// Repositorio para asignaciones de usuarios a proyectos.
///
/// Colección Firestore: `projectAssignments/{autoId}`
class ProjectAssignmentRepository {
  ProjectAssignmentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('projectAssignments');

  /// Obtiene las asignaciones de un usuario.
  Future<List<ProjectAssignment>> getAssignmentsByUser(String userId) async {
    final snapshot = await _ref
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(ProjectAssignment.fromFirestore).toList();
  }

  /// Stream de asignaciones de un usuario.
  Stream<List<ProjectAssignment>> watchAssignmentsByUser(String userId) {
    return _ref
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(ProjectAssignment.fromFirestore).toList());
  }

  /// Obtiene los usuarios asignados a un proyecto.
  Future<List<ProjectAssignment>> getAssignmentsByProject(
    String projectId,
  ) async {
    final snapshot = await _ref
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map(ProjectAssignment.fromFirestore).toList();
  }

  /// Stream de asignaciones de un proyecto.
  Stream<List<ProjectAssignment>> watchAssignmentsByProject(String projectId) {
    return _ref
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(ProjectAssignment.fromFirestore).toList());
  }

  /// Asigna un usuario a un proyecto con un rol.
  Future<String> assignUserToProject({
    required String userId,
    required String projectId,
    required String empresaId,
    required UserRole role,
    required String assignedBy,
  }) async {
    final assignment = ProjectAssignment(
      id: '', // Se genera al crear
      userId: userId,
      projectId: projectId,
      empresaId: empresaId,
      role: role,
      assignedAt: DateTime.now(),
      assignedBy: assignedBy,
      isActive: true,
    );

    final docRef = await _ref.add(assignment.toFirestore());
    return docRef.id;
  }

  /// Cambia el rol en una asignación existente.
  Future<void> updateRole(String assignmentId, UserRole newRole) async {
    await _ref.doc(assignmentId).update({'role': newRole.label});
  }

  /// Desactiva una asignación (no la borra).
  Future<void> deactivateAssignment(String assignmentId) async {
    await _ref.doc(assignmentId).update({'isActive': false});
  }

  /// Verifica si un usuario ya está asignado a un proyecto.
  Future<bool> isUserAssigned(String userId, String projectId) async {
    final snapshot = await _ref
        .where('userId', isEqualTo: userId)
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
