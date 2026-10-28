class Intento {
  const Intento({
    this.id,
    required this.palabraId,
    required this.fecha,
    required this.acierto,
    this.textoReconocido,
  });

  final int? id;
  final int palabraId;
  final DateTime fecha;
  final bool acierto;
  final String? textoReconocido;

  Map<String, Object?> toMap() => {
        'id': id,
        'palabra_id': palabraId,
        'fecha': fecha.toIso8601String(),
        'acierto': acierto ? 1 : 0,
        'texto_reconocido': textoReconocido,
      };

  factory Intento.fromMap(Map<String, Object?> map) => Intento(
        id: map['id'] as int?,
        palabraId: map['palabra_id'] as int,
        fecha: DateTime.parse(map['fecha'] as String),
        acierto: map['acierto'] == 1,
        textoReconocido: map['texto_reconocido'] as String?,
      );
}