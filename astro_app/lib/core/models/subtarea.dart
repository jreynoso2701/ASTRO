/// Modelo de Subtarea (embebido dentro de una Tarea).
class Subtarea {
  const Subtarea({
    required this.id,
    required this.titulo,
    this.completada = false,
    this.orden = 0,
  });

  final String id;
  final String titulo;
  final bool completada;
  final int orden;

  factory Subtarea.fromMap(Map<String, dynamic> map) {
    return Subtarea(
      id: map['id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      completada: map['completada'] as bool? ?? false,
      orden: (map['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'completada': completada,
      'orden': orden,
    };
  }

  Subtarea copyWith({String? titulo, bool? completada, int? orden}) {
    return Subtarea(
      id: id,
      titulo: titulo ?? this.titulo,
      completada: completada ?? this.completada,
      orden: orden ?? this.orden,
    );
  }
}
