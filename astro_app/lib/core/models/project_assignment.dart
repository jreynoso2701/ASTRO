import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/user_role.dart';

/// Asignación de un usuario a un proyecto con un rol específico.
///
/// Colección Firestore: `projectAssignments/{autoId}`
class ProjectAssignment {
  const ProjectAssignment({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.empresaId,
    required this.role,
    required this.assignedAt,
    required this.assignedBy,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String projectId;
  final String empresaId;
  final UserRole role;
  final DateTime assignedAt;
  final String assignedBy;
  final bool isActive;

  factory ProjectAssignment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return ProjectAssignment(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      empresaId: data['empresaId'] as String? ?? '',
      role: UserRole.fromString(data['role'] as String? ?? 'Usuario'),
      assignedAt: parseDate(data['assignedAt']),
      assignedBy: data['assignedBy'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'projectId': projectId,
      'empresaId': empresaId,
      'role': role.label,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'assignedBy': assignedBy,
      'isActive': isActive,
    };
  }

  ProjectAssignment copyWith({UserRole? role, bool? isActive}) {
    return ProjectAssignment(
      id: id,
      userId: userId,
      projectId: projectId,
      empresaId: empresaId,
      role: role ?? this.role,
      assignedAt: assignedAt,
      assignedBy: assignedBy,
      isActive: isActive ?? this.isActive,
    );
  }
}
