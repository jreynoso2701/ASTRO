import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Modelo de Etiqueta (Label).
///
/// Colección Firestore: `Etiquetas/{docId}`.
/// - `esGlobal: true`  → etiqueta de plataforma (visible en todos los proyectos).
/// - `esGlobal: false` → etiqueta específica de un proyecto (`projectId` requerido).
class Etiqueta {
  const Etiqueta({
    required this.id,
    required this.nombre,
    required this.colorHex,
    required this.createdByUid,
    required this.createdByName,
    required this.esGlobal,
    this.icono,
    this.projectId,
    this.projectName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nombre;

  /// Color en formato hexadecimal (e.g. "#FF5722"). Con o sin '#'.
  final String colorHex;

  /// Nombre del ícono de Material Icons (e.g. "bug_report", "label"). Opcional.
  final String? icono;

  final bool esGlobal;

  /// Solo aplica cuando `esGlobal == false`.
  final String? projectId;
  final String? projectName;

  final String createdByUid;
  final String createdByName;
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── Derived ──────────────────────────────────────────────

  /// Color como objeto Flutter.
  Color get color {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return Colors.grey;
  }

  // ── Firestore ─────────────────────────────────────────────

  factory Etiqueta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
      return null;
    }

    return Etiqueta(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      colorHex: data['colorHex'] as String? ?? '#666666',
      icono: data['icono'] as String?,
      esGlobal: data['esGlobal'] as bool? ?? false,
      projectId: data['projectId'] as String?,
      projectName: data['projectName'] as String?,
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'colorHex': colorHex,
      if (icono != null) 'icono': icono,
      'esGlobal': esGlobal,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Etiqueta copyWith({
    String? nombre,
    String? colorHex,
    String? icono,
    bool? clearIcono,
    bool? esGlobal,
    String? projectId,
    String? projectName,
    bool? isActive,
  }) {
    return Etiqueta(
      id: id,
      nombre: nombre ?? this.nombre,
      colorHex: colorHex ?? this.colorHex,
      icono: clearIcono == true ? null : (icono ?? this.icono),
      esGlobal: esGlobal ?? this.esGlobal,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      createdByUid: createdByUid,
      createdByName: createdByName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Colores predefinidos para el selector de etiquetas.
const kEtiquetaPresetColors = <String>[
  '#F44336', // Red
  '#E91E63', // Pink
  '#9C27B0', // Purple
  '#673AB7', // Deep Purple
  '#3F51B5', // Indigo
  '#2196F3', // Blue
  '#03A9F4', // Light Blue
  '#00BCD4', // Cyan
  '#009688', // Teal
  '#4CAF50', // Green
  '#8BC34A', // Light Green
  '#CDDC39', // Lime
  '#FFEB3B', // Yellow
  '#FFC107', // Amber
  '#FF9800', // Orange
  '#FF5722', // Deep Orange
  '#795548', // Brown
  '#9E9E9E', // Grey
  '#607D8B', // Blue Grey
  '#FFFFFF', // White
];

/// Íconos predefinidos para etiquetas (nombres de Material Icons).
const kEtiquetaPresetIcons = <String>[
  'label',
  'bug_report',
  'code',
  'design_services',
  'storage',
  'cloud',
  'phone_android',
  'web',
  'security',
  'speed',
  'build',
  'star',
  'priority_high',
  'flag',
  'bookmark',
  'tag',
  'work',
  'school',
  'science',
  'auto_awesome',
];
