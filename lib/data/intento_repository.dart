import '../models/intento.dart';
import 'database_helper.dart';

class IntentoRepository {
  IntentoRepository([DatabaseHelper? databaseHelper])
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

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
