import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/user_role.dart';

/// Modelo de usuario de ASTRO.
///
/// Colección Firestore: `users/{uid}`
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.isActive,
    required this.isRoot,
    required this.createdAt,
    required this.updatedAt,
    this.phoneNumber,
    this.photoUrl,
    this.defaultEmpresaId,
    // Campos legacy V1 para compatibilidad de lectura
    this.legacyDeEmpresa,
    this.legacyRolUsuario,
    this.legacyProyectosAsignados,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isActive;
  final bool isRoot;
  final String? defaultEmpresaId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Legacy V1 fields (solo lectura, no se escriben en docs nuevos)
  final String? legacyDeEmpresa;
  final String? legacyRolUsuario;
  final List<String>? legacyProyectosAsignados;

  /// Rol efectivo global — Root si `isRoot`, de lo contrario se determina
  /// por sus `projectAssignments`.
  UserRole get globalRole => isRoot ? UserRole.root : UserRole.usuario;

  /// Crea un [AppUser] desde un documento de Firestore.
  /// Compatible con V1 (campos legacy) y V2 (campos nuevos).
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Parsear timestamp — soporta tanto Timestamp de Firestore como string ISO
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    // Parsear array de strings (V1: proyectosAsignados)
    List<String>? parseStringList(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      return null;
    }

    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      displayName:
          data['displayName'] as String? ??
          data['display_name'] as String? ??
          '',
      email: data['email'] as String? ?? '',
      phoneNumber:
          data['phoneNumber'] as String? ?? data['phone_number'] as String?,
      photoUrl: data['photoUrl'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      isRoot: data['isRoot'] as bool? ?? false,
      defaultEmpresaId: data['defaultEmpresaId'] as String?,
      createdAt: parseDate(data['createdAt'] ?? data['created_time']),
      updatedAt: parseDate(
        data['updatedAt'] ?? data['createdAt'] ?? data['created_time'],
      ),
      // Legacy
      legacyDeEmpresa: data['deEmpresa'] as String?,
      legacyRolUsuario: data['rolUsuario'] as String?,
      legacyProyectosAsignados: parseStringList(data['proyectosAsignados']),
    );
  }

  /// Serializa a mapa para escritura en Firestore (formato V2).
  /// NO incluye campos legacy — esos se preservan aparte.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'isActive': isActive,
      'isRoot': isRoot,
      if (defaultEmpresaId != null) 'defaultEmpresaId': defaultEmpresaId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Crea una copia modificada.
  AppUser copyWith({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    bool? isActive,
    bool? isRoot,
    String? defaultEmpresaId,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      isRoot: isRoot ?? this.isRoot,
      defaultEmpresaId: defaultEmpresaId ?? this.defaultEmpresaId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      legacyDeEmpresa: legacyDeEmpresa,
      legacyRolUsuario: legacyRolUsuario,
      legacyProyectosAsignados: legacyProyectosAsignados,
    );
  }
}
