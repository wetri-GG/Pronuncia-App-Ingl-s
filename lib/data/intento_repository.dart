import '../models/intento.dart';
import '../models/palabra.dart';
import 'database_helper.dart';

class IntentoRepository {
  IntentoRepository([DatabaseHelper? databaseHelper])
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<List<({int temaId, int intentos, int aciertos})>>
  obtenerEstadisticasPorTema() async {
    final db = await _databaseHelper.database;
    final filas = await db.rawQuery('''
      SELECT
        t.id AS tema_id,
        COUNT(i.id) AS total_intentos,
        COALESCE(SUM(CASE WHEN i.acierto = 1 THEN 1 ELSE 0 END), 0) AS aciertos
      FROM temas t
      LEFT JOIN palabras p ON p.tema_id = t.id
      LEFT JOIN intentos i ON i.palabra_id = p.id
      GROUP BY t.id, t.nombre
      ORDER BY t.nombre
    ''');
    return filas
        .map(
          (fila) => (
            temaId: fila['tema_id'] as int,
            intentos: fila['total_intentos'] as int,
            aciertos: fila['aciertos'] as int,
          ),
        )
        .toList();
  }

  Future<List<({Palabra palabra, int fallos})>> obtenerPalabrasMasFalladas({
    int limite = 5,
  }) async {
    if (limite < 1) {
      throw ArgumentError.value(limite, 'limite', 'Debe ser mayor que cero.');
    }

    final db = await _databaseHelper.database;
    final filas = await db.rawQuery(
      '''
      SELECT
        p.id,
        p.tema_id,
        p.ingles,
        p.espanol,
        COUNT(i.id) AS fallos
      FROM palabras p
      INNER JOIN intentos i ON i.palabra_id = p.id
      WHERE i.acierto = 0
      GROUP BY p.id, p.tema_id, p.ingles, p.espanol
      ORDER BY fallos DESC, p.ingles COLLATE NOCASE
      LIMIT ?
      ''',
      [limite],
    );
    return filas.map((fila) {
      final valoresPalabra = Map<String, Object?>.from(fila)..remove('fallos');
      return (
        palabra: Palabra.fromMap(valoresPalabra),
        fallos: fila['fallos'] as int,
      );
    }).toList();
  }

  Future<int> crear(Intento intento) async {
    final db = await _databaseHelper.database;
    final valores = intento.toMap()..remove('id');
    return db.insert('intentos', valores);
  }

  Future<List<Intento>> obtenerTodos() async {
    final db = await _databaseHelper.database;
    final filas = await db.query('intentos', orderBy: 'fecha DESC');
    return filas.map(Intento.fromMap).toList();
  }

  Future<List<Intento>> obtenerPorPalabra(int palabraId) async {
    final db = await _databaseHelper.database;
    final filas = await db.query(
      'intentos',
      where: 'palabra_id = ?',
      whereArgs: [palabraId],
      orderBy: 'fecha DESC',
    );
    return filas.map(Intento.fromMap).toList();
  }

  Future<Intento?> obtenerPorId(int id) async {
    final db = await _databaseHelper.database;
    final filas = await db.query(
      'intentos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Intento.fromMap(filas.first);
  }

  Future<int> actualizar(Intento intento) async {
    final id = intento.id;
    if (id == null) {
      throw ArgumentError('No se puede actualizar un intento sin id.');
    }

    final db = await _databaseHelper.database;
    final valores = intento.toMap()..remove('id');
    return db.update('intentos', valores, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminar(int id) async {
    final db = await _databaseHelper.database;
    return db.delete('intentos', where: 'id = ?', whereArgs: [id]);
  }
}
