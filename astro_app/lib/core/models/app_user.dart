import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/registration_status.dart';
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
    this.fcmTokens = const [],
    this.pushGlobalEnabled = true,
    this.registrationStatus = RegistrationStatus.approved,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    this.rejectedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isActive;
  final bool isRoot;
  final String? defaultEmpresaId;
  final List<String> fcmTokens;
  final bool pushGlobalEnabled;
  final RegistrationStatus registrationStatus;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `true` si el usuario está aprobado (o es usuario legacy sin campo).
  bool get isApproved => registrationStatus == RegistrationStatus.approved;

  /// `true` si el registro está pendiente de aprobación.
  bool get isPending => registrationStatus == RegistrationStatus.pending;

  /// `true` si el registro fue rechazado.
  bool get isRejected => registrationStatus == RegistrationStatus.rejected;

  /// Rol efectivo global — Root si `isRoot`, de lo contrario Usuario.
  /// Los roles por proyecto se gestionan vía `projectAssignments`.
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
      fcmTokens:
          (data['fcmTokens'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      pushGlobalEnabled: data['pushGlobalEnabled'] as bool? ?? true,
      registrationStatus: RegistrationStatus.fromString(
        data['registrationStatus'] as String?,
      ),
      rejectionReason: data['rejectionReason'] as String?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] != null
          ? parseDate(data['approvedAt'])
          : null,
      rejectedAt: data['rejectedAt'] != null
          ? parseDate(data['rejectedAt'])
          : null,
      createdAt: parseDate(data['createdAt'] ?? data['created_time']),
      updatedAt: parseDate(
        data['updatedAt'] ?? data['createdAt'] ?? data['created_time'],
      ),
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
      'fcmTokens': fcmTokens,
      'pushGlobalEnabled': pushGlobalEnabled,
      'registrationStatus': registrationStatus.value,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (rejectedAt != null) 'rejectedAt': Timestamp.fromDate(rejectedAt!),
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
    List<String>? fcmTokens,
    bool? pushGlobalEnabled,
    RegistrationStatus? registrationStatus,
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? rejectedAt,
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
      fcmTokens: fcmTokens ?? this.fcmTokens,
      pushGlobalEnabled: pushGlobalEnabled ?? this.pushGlobalEnabled,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
