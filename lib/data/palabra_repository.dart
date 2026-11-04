import '../models/palabra.dart';
import 'database_helper.dart';

class PalabraRepository {
  PalabraRepository([DatabaseHelper? databaseHelper])
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> crear(Palabra palabra) async {
    final db = await _databaseHelper.database;
    final valores = palabra.toMap()..remove('id');
    return db.insert('palabras', valores);
  }

  Future<List<Palabra>> obtenerTodos() async {
    final db = await _databaseHelper.database;
    final filas = await db.query('palabras', orderBy: 'id');
    return filas.map(Palabra.fromMap).toList();
  }

  Future<List<Palabra>> obtenerPorTema(int temaId) async {
    final db = await _databaseHelper.database;
    final filas = await db.query(
      'palabras',
      where: 'tema_id = ?',
      whereArgs: [temaId],
      orderBy: 'id',
    );
    return filas.map(Palabra.fromMap).toList();
  }

  Future<Palabra?> obtenerPorId(int id) async {
    final db = await _databaseHelper.database;
    final filas = await db.query(
      'palabras',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Palabra.fromMap(filas.first);
  }

  Future<int> actualizar(Palabra palabra) async {
    final id = palabra.id;
    if (id == null) {
      throw ArgumentError('No se puede actualizar una palabra sin id.');
    }

    final db = await _databaseHelper.database;
    final valores = palabra.toMap()..remove('id');
    return db.update('palabras', valores, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminar(int id) async {
    final db = await _databaseHelper.database;
    return db.delete('palabras', where: 'id = ?', whereArgs: [id]);
  }
}
