class Palabra {
  const Palabra({
    this.id,
    required this.temaId,
    required this.ingles,
    required this.espanol,
  });

  final int? id;
  final int temaId;
  final String ingles;
  final String espanol;

  Map<String, Object?> toMap() => {
        'id': id,
        'tema_id': temaId,
        'ingles': ingles,
        'espanol': espanol,
      };

  factory Palabra.fromMap(Map<String, Object?> map) => Palabra(
        id: map['id'] as int?,
        temaId: map['tema_id'] as int,
        ingles: map['ingles'] as String,
        espanol: map['espanol'] as String,
      );
}