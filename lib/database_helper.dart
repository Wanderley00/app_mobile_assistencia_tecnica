// lib/database_helper.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/registro_ponto.dart';
import 'models/ordem_servico.dart';
import 'models/despesa.dart';
import 'models/documento_os.dart';
import 'models/relatorio_campo.dart';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currentUserId');
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'os_database.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ordens_servico (
        id INTEGER,
        user_id TEXT NOT NULL,
        json_data TEXT NOT NULL,
        PRIMARY KEY (user_id, id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        os_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('CREATE INDEX idx_os_user ON ordens_servico(user_id, id)');
    await db.execute(
        'CREATE INDEX idx_pa_user_time ON pending_actions(user_id, timestamp)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      final cols = await db.rawQuery("PRAGMA table_info(ordens_servico)");
      final hasUserIdOs = cols.any((c) => c['name'] == 'user_id');

      if (!hasUserIdOs) {
        await db.execute('ALTER TABLE ordens_servico ADD COLUMN user_id TEXT');
        final currentUserId = (await _getCurrentUserId()) ?? '__unknown__';
        await db.update('ordens_servico', {'user_id': currentUserId},
            where: 'user_id IS NULL');
        await db.execute('''
          CREATE TABLE ordens_servico_new (
            id INTEGER,
            user_id TEXT NOT NULL,
            json_data TEXT NOT NULL,
            PRIMARY KEY (user_id, id)
          )
        ''');
        final rows = await db.query('ordens_servico');
        for (final r in rows) {
          await db.insert(
              'ordens_servico_new',
              {
                'id': r['id'],
                'user_id': r['user_id'],
                'json_data': r['json_data'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await db.execute('DROP TABLE ordens_servico');
        await db
            .execute('ALTER TABLE ordens_servico_new RENAME TO ordens_servico');
        await db
            .execute('CREATE INDEX idx_os_user ON ordens_servico(user_id, id)');
      }

      final cols2 = await db.rawQuery("PRAGMA table_info(pending_actions)");
      final hasUserIdPa = cols2.any((c) => c['name'] == 'user_id');
      if (!hasUserIdPa) {
        await db.execute('ALTER TABLE pending_actions ADD COLUMN user_id TEXT');
        final currentUserId = (await _getCurrentUserId()) ?? '__unknown__';
        await db.update('pending_actions', {'user_id': currentUserId},
            where: 'user_id IS NULL');
        await db.execute(
            'CREATE INDEX idx_pa_user_time ON pending_actions(user_id, timestamp)');
      }
    }
  }

  Future cacheOrdensServico(List<OrdemServico> ordens) async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return;
    await db.transaction((txn) async {
      await txn
          .delete('ordens_servico', where: 'user_id = ?', whereArgs: [userId]);
      for (var os in ordens) {
        await txn.insert(
          'ordens_servico',
          {
            'id': os.id,
            'user_id': userId,
            'json_data': jsonEncode(os.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future cacheOrdemServicoDetalhes(OrdemServico os) async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return;
    await db.insert(
      'ordens_servico',
      {
        'id': os.id,
        'user_id': userId,
        'json_data': jsonEncode(os.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OrdemServico>> getOrdensServicoFromCache() async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return [];
    final maps = await db
        .query('ordens_servico', where: 'user_id = ?', whereArgs: [userId]);
    if (maps.isEmpty) return [];
    return maps
        .map((m) => OrdemServico.fromJson(jsonDecode(m['json_data'] as String)))
        .toList();
  }

  Future<OrdemServico?> getOrdemServicoById(int id) async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return null;
    final maps = await db.query(
      'ordens_servico',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return OrdemServico.fromJson(
          jsonDecode(maps.first['json_data'] as String));
    }
    return null;
  }

  Future addPendingAction(
      int osId, String action, Map<String, dynamic> payload) async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return;
    await db.insert('pending_actions', {
      'user_id': userId,
      'os_id': osId,
      'action': action,
      'payload': jsonEncode(payload),
    });
  }

  Future<List<Map<String, Object?>>> getPendingActions() async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return [];
    return await db.query('pending_actions',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'timestamp ASC');
  }

  Future<List<Map<String, Object?>>> getPendingActionsForOs(int osId) async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return [];
    return await db.query(
      'pending_actions',
      where: 'user_id = ? AND os_id = ?',
      whereArgs: [userId, osId],
      orderBy: 'timestamp ASC',
    );
  }

  Future deletePendingAction(int id) async {
    final db = await database;
    await db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future addDespesaToCache(int osId, Despesa despesa) async {
    final existingOs = await getOrdemServicoById(osId);
    if (existingOs != null) {
      existingOs.despesas.add(despesa);
      await cacheOrdemServicoDetalhes(existingOs);
    }
  }

  Future addDocumentoToCache(int osId, DocumentoOS documento) async {
    final existingOs = await getOrdemServicoById(osId);
    if (existingOs != null) {
      existingOs.documentos.add(documento);
      await cacheOrdemServicoDetalhes(existingOs);
    }
  }

  Future cachePontos(List<RegistroPonto> pontos, int osId) async {
    final os = await getOrdemServicoById(osId);
    if (os != null) {
      final osAtualizada = os.copyWith(pontos: pontos);
      await cacheOrdemServicoDetalhes(osAtualizada);
    }
  }

  Future<List<RegistroPonto>> getPontosFromCache(int osId) async {
    final os = await getOrdemServicoById(osId);
    return os?.pontos ?? [];
  }

  Future clearOsCache(int osId) async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return;
    await db.delete('ordens_servico',
        where: 'user_id = ? AND id = ?', whereArgs: [userId, osId]);
  }

  Future<List<int>> getDistinctOsIdsFromPendingActions() async {
    final db = await database;
    final userId = await _getCurrentUserId();
    if (userId == null) return [];
    final maps = await db.query('pending_actions',
        distinct: true,
        columns: ['os_id'],
        where: 'user_id = ?',
        whereArgs: [userId]);
    if (maps.isEmpty) return [];
    return maps.map((m) => m['os_id'] as int).toList();
  }

  Future clearAllUserData() async {
    // Intencionalmente vazio: cache agora é multiusuário e não é apagado no logout
  }

  Future addRelatorioToCache(int osId, RelatorioCampo relatorio) async {
    final osDoCache = await getOrdemServicoById(osId);
    if (osDoCache != null) {
      final rels = List<RelatorioCampo>.from(osDoCache.relatorios);
      rels.insert(0, relatorio);
      final osAtualizada = osDoCache.copyWith(relatorios: rels);
      await cacheOrdemServicoDetalhes(osAtualizada);
    }
  }

  Future<bool> checkIfReportExists(
      int osId, int tipoRelatorioId, DateTime data) async {
    final osDoCache = await getOrdemServicoById(osId);
    if (osDoCache == null) return false;
    final d = DateUtils.dateOnly(data);
    final existe = osDoCache.relatorios.any((r) {
      final dr = DateUtils.dateOnly(r.dataRelatorio);
      return r.tipoRelatorio.id == tipoRelatorioId && dr == d;
    });
    return existe;
  }
}
