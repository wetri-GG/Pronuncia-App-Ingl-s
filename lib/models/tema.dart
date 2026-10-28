class Tema {
  const Tema({this.id, required this.nombre});

  final int? id;
  final String nombre;

  Map<String, Object?> toMap() => {
        'id': id,
        'nombre': nombre,
      };

  factory Tema.fromMap(Map<String, Object?> map) => Tema(
        id: map['id'] as int?,
        nombre: map['nombre'] as String,
      );
}