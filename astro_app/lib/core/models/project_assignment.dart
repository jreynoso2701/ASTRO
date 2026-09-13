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
    this.isLead = false,
  });

  final String id;
  final String userId;
  final String projectId;
  final String empresaId;
  final UserRole role;
  final DateTime assignedAt;
  final String assignedBy;
  final bool isActive;

  /// Marca a este miembro como responsable principal del proyecto.
  ///
  /// Se apoya en la asignación en vez de en un campo del proyecto para que un
  /// responsable sea siempre alguien que ya pertenece al proyecto: al
  /// desactivar la asignación se pierde también la responsabilidad.
  final bool isLead;

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
      isLead: data['isLead'] as bool? ?? false,
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
      'isLead': isLead,
    };
  }

  ProjectAssignment copyWith({UserRole? role, bool? isActive, bool? isLead}) {
    return ProjectAssignment(
      id: id,
      userId: userId,
      projectId: projectId,
      empresaId: empresaId,
      role: role ?? this.role,
      assignedAt: assignedAt,
      assignedBy: assignedBy,
      isActive: isActive ?? this.isActive,
      isLead: isLead ?? this.isLead,
    );
  }
}
