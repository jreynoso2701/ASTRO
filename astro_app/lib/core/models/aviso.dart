import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:astro/core/models/aviso_prioridad.dart';

/// Estado de lectura de un aviso por un usuario.
class AvisoLectura {
  const AvisoLectura({required this.uid, this.leido = false, this.leidoAt});

  final String uid;
  final bool leido;
  final DateTime? leidoAt;

  factory AvisoLectura.fromMap(String uid, Map<String, dynamic> data) {
    return AvisoLectura(
      uid: uid,
      leido: data['leido'] as bool? ?? false,
      leidoAt: (data['leidoAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'leido': leido,
    if (leidoAt != null) 'leidoAt': Timestamp.fromDate(leidoAt!),
  };
}

/// Modelo de Aviso (notificación/anuncio dentro de un proyecto).
///
/// Colección Firestore: `Avisos/{docId}`.
class Aviso {
  const Aviso({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.prioridad,
    required this.projectId,
    required this.projectName,
    required this.createdBy,
    required this.createdByName,
    this.destinatarios = const [],
    this.todosLosUsuarios = true,
    this.lecturas = const {},
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String titulo;
  final String mensaje;
  final AvisoPrioridad prioridad;
  final String projectId;
  final String projectName;
  final String createdBy;
  final String createdByName;

  /// UIDs de destinatarios específicos. Vacío si [todosLosUsuarios] es true.
  final List<String> destinatarios;

  /// Si true, se envía a todos los miembros del proyecto.
  final bool todosLosUsuarios;

  /// Estado de lectura por usuario: Map<uid, AvisoLectura>.
  final Map<String, AvisoLectura> lecturas;

  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Computed ─────────────────────────────────────────

  /// Cantidad de destinatarios que ya leyeron el aviso.
  int get leidoCount => lecturas.values.where((l) => l.leido).length;

  /// Cantidad total de destinatarios rastreados.
  int get totalDestinatarios => lecturas.length;

  /// Si todos los destinatarios leyeron el aviso.
  bool get todosLeyeron =>
      lecturas.isNotEmpty && leidoCount == totalDestinatarios;

  /// Si el aviso ha expirado.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  // ── Firestore ────────────────────────────────────────

  factory Aviso.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Parsear lecturas: Map<uid, {leido, leidoAt}>
    final lecturasRaw = data['lecturas'] as Map<String, dynamic>? ?? {};
    final lecturas = lecturasRaw.map(
      (uid, value) => MapEntry(
        uid,
        AvisoLectura.fromMap(uid, value as Map<String, dynamic>),
      ),
    );

    return Aviso(
      id: doc.id,
      titulo: data['titulo'] as String? ?? '',
      mensaje: data['mensaje'] as String? ?? '',
      prioridad: AvisoPrioridad.fromString(
        data['prioridad'] as String? ?? 'informativo',
      ),
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      destinatarios: List<String>.from(data['destinatarios'] ?? []),
      todosLosUsuarios: data['todosLosUsuarios'] as bool? ?? true,
      lecturas: lecturas,
      isActive: data['isActive'] as bool? ?? true,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final now = DateTime.now();
    return {
      'titulo': titulo,
      'mensaje': mensaje,
      'prioridad': prioridad.value,
      'projectId': projectId,
      'projectName': projectName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'destinatarios': destinatarios,
      'todosLosUsuarios': todosLosUsuarios,
      'lecturas': lecturas.map((uid, l) => MapEntry(uid, l.toMap())),
      'isActive': isActive,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Aviso copyWith({
    String? titulo,
    String? mensaje,
    AvisoPrioridad? prioridad,
    List<String>? destinatarios,
    bool? todosLosUsuarios,
    Map<String, AvisoLectura>? lecturas,
    bool? isActive,
    DateTime? expiresAt,
  }) {
    return Aviso(
      id: id,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      prioridad: prioridad ?? this.prioridad,
      projectId: projectId,
      projectName: projectName,
      createdBy: createdBy,
      createdByName: createdByName,
      destinatarios: destinatarios ?? this.destinatarios,
      todosLosUsuarios: todosLosUsuarios ?? this.todosLosUsuarios,
      lecturas: lecturas ?? this.lecturas,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
