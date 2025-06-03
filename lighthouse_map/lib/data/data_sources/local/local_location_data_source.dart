import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lighthouse_map/data/models/location_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
//import '../../models/location_model.dart';

class LocalLocationDataSource {
  static Database? _database;
  static const String tableName = 'locations_offline';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'lighthouse_map.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName(
            locationId TEXT PRIMARY KEY,
            userId TEXT,
            deviceId TEXT,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER,   -- Cambiado a INTEGER para milisegundos desde época
            createdAt INTEGER    -- Cambiado a INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertLocation(LocationModel location) async {
    final db = await database;
    await db.insert(
      tableName,
      {
        'locationId': location.locationId,
        'userId': location.userId,
        'deviceId': location.deviceId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': location.timestamp?.millisecondsSinceEpoch, // <-- ¡CAMBIO AQUÍ!
        'createdAt': location.createdAt?.millisecondsSinceEpoch, // <-- ¡Y AQUÍ!
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[MYLOG]Ubicación guardada localmente: ${location.locationId}');
  }

  Future<List<LocationModel>> getPendingLocations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);

    return List.generate(maps.length, (i) {
      return LocationModel.fromMap({
        'location_id': maps[i]['locationId'], // Ajusta el nombre de la columna si es diferente
        'user_id': maps[i]['userId'],
        'device_id': maps[i]['deviceId'],
        'latitude': maps[i]['latitude'],
        'longitude': maps[i]['longitude'],
        'timestamp': maps[i]['timestamp'] != null ? Timestamp.fromMillisecondsSinceEpoch(maps[i]['timestamp']) : null, // <-- Asegúrate de que esto se convierta a Timestamp
        'created_at': maps[i]['createdAt'] != null ? Timestamp.fromMillisecondsSinceEpoch(maps[i]['createdAt']) : null, // <-- Y esto
      });
    });
  }

  Future<void> deleteLocation(String locationId) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'locationId = ?',
      whereArgs: [locationId],
    );
    debugPrint('[MYLOG]Ubicación eliminada localmente: $locationId');
  }

  Future<void> deleteAllLocations() async {
    final db = await database;
    await db.delete(tableName);
    debugPrint('[MYLOG]Todas las ubicaciones locales eliminadas.');
  }
}