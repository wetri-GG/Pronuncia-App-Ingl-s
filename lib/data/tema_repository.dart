import '../models/tema.dart';
import 'database_helper.dart';

class TemaRepository {
  TemaRepository([DatabaseHelper? databaseHelper])
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> crear(Tema tema) async {
    final db = await _databaseHelper.database;
    final valores = tema.toMap()..remove('id');
    return db.insert('temas', valores);
  }

  Future<List<Tema>> obtenerTodos() async {
    final db = await _databaseHelper.database;
    final filas = await db.query('temas', orderBy: 'nombre');
    return filas.map(Tema.fromMap).toList();
  }

  Future<Tema?> obtenerPorId(int id) async {
    final db = await _databaseHelper.database;
    final filas = await db.query(
      'temas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return filas.isEmpty ? null : Tema.fromMap(filas.first);
  }

  Future<int> actualizar(Tema tema) async {
    final id = tema.id;
    if (id == null) {
      throw ArgumentError('No se puede actualizar un tema sin id.');
    }

    final db = await _databaseHelper.database;
    final valores = tema.toMap()..remove('id');
    return db.update('temas', valores, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminar(int id) async {
    final db = await _databaseHelper.database;
    return db.delete('temas', where: 'id = ?', whereArgs: [id]);
  }
}
