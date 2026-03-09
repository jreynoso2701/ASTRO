import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/user_role.dart';

/// Alcance de notificaciones por categoría.
///
/// - [participante]: Solo donde el usuario participa directamente.
/// - [proyecto]: Todos los del proyecto asignado.
/// - [todos]: Todos los de todos los proyectos (Root).
enum NotificationScope {
  participante('participante'),
  proyecto('proyecto'),
  todos('todos');

  const NotificationScope(this.value);
  final String value;

  static NotificationScope fromString(String value) {
    return NotificationScope.values.firstWhere(
      (s) => s.value == value,
      orElse: () => NotificationScope.participante,
    );
  }

  /// Alcance por defecto según el rol del usuario.
  static NotificationScope defaultForRole(UserRole role) {
    return switch (role) {
      UserRole.root => NotificationScope.todos,
      UserRole.supervisor => NotificationScope.proyecto,
      UserRole.soporte => NotificationScope.proyecto,
      UserRole.usuario => NotificationScope.participante,
    };
  }
}

/// Configuración de notificaciones de un usuario para un proyecto.
///
/// Colección Firestore: `NotificationConfig/{projectId_userId}`
///
/// Si no existe un documento para un usuario/proyecto,
/// se aplican las reglas por defecto según su rol.
class NotificationConfig {
  const NotificationConfig({
    required this.id,
    required this.projectId,
    required this.userId,
    this.pushEnabled = true,
    this.recibirTickets = true,
    this.scopeTickets = NotificationScope.participante,
    this.recibirRequerimientos = true,
    this.scopeRequerimientos = NotificationScope.participante,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String projectId;
  final String userId;

  /// Master toggle — si es false, no recibe ninguna notificación del proyecto.
  final bool pushEnabled;

  /// Recibir notificaciones de tickets.
  final bool recibirTickets;

  /// Alcance de notificaciones de tickets.
  final NotificationScope scopeTickets;

  /// Recibir notificaciones de requerimientos.
  final bool recibirRequerimientos;

  /// Alcance de notificaciones de requerimientos.
  final NotificationScope scopeRequerimientos;

  final DateTime? updatedAt;
  final String? updatedBy;

  /// Genera la configuración por defecto según el rol.
  factory NotificationConfig.defaultForRole({
    required String projectId,
    required String userId,
    required UserRole role,
  }) {
    final scope = NotificationScope.defaultForRole(role);
    return NotificationConfig(
      id: '${projectId}_$userId',
      projectId: projectId,
      userId: userId,
      pushEnabled: true,
      recibirTickets: true,
      scopeTickets: scope,
      recibirRequerimientos: true,
      scopeRequerimientos: scope,
    );
  }

  factory NotificationConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return NotificationConfig(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      pushEnabled: data['pushEnabled'] as bool? ?? true,
      recibirTickets: data['recibirTickets'] as bool? ?? true,
      scopeTickets: NotificationScope.fromString(
        data['scopeTickets'] as String? ?? 'participante',
      ),
      recibirRequerimientos: data['recibirRequerimientos'] as bool? ?? true,
      scopeRequerimientos: NotificationScope.fromString(
        data['scopeRequerimientos'] as String? ?? 'participante',
      ),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'userId': userId,
      'pushEnabled': pushEnabled,
      'recibirTickets': recibirTickets,
      'scopeTickets': scopeTickets.value,
      'recibirRequerimientos': recibirRequerimientos,
      'scopeRequerimientos': scopeRequerimientos.value,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  NotificationConfig copyWith({
    bool? pushEnabled,
    bool? recibirTickets,
    NotificationScope? scopeTickets,
    bool? recibirRequerimientos,
    NotificationScope? scopeRequerimientos,
    String? updatedBy,
  }) {
    return NotificationConfig(
      id: id,
      projectId: projectId,
      userId: userId,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      recibirTickets: recibirTickets ?? this.recibirTickets,
      scopeTickets: scopeTickets ?? this.scopeTickets,
      recibirRequerimientos:
          recibirRequerimientos ?? this.recibirRequerimientos,
      scopeRequerimientos: scopeRequerimientos ?? this.scopeRequerimientos,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
