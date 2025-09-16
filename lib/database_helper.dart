// lib/database_helper.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'os_database.db');
    return await openDatabase(
      path,
      version: 2, // Usando a versão 2 como no exemplo de migração
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ordens_servico (
        id INTEGER PRIMARY KEY,
        json_data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        os_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Exemplo de migração, pode ser ajustado conforme necessário
      await db.execute('''
        ALTER TABLE ordens_servico ADD COLUMN temp_col TEXT
      ''');
    }
  }

  // MÉTODOS DE CACHE PARA ORDENS DE SERVIÇO
  Future<void> cacheOrdensServico(List<OrdemServico> ordens) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ordens_servico');
      for (var os in ordens) {
        await txn.insert(
            'ordens_servico',
            {
              'id': os.id,
              'json_data': jsonEncode(os.toJson()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> cacheOrdemServicoDetalhes(OrdemServico os) async {
    final db = await database;
    await db.insert(
        'ordens_servico',
        {
          'id': os.id,
          'json_data': jsonEncode(os.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OrdemServico>> getOrdensServicoFromCache() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('ordens_servico');
    if (maps.isEmpty) return [];
    return maps
        .map((map) => OrdemServico.fromJson(jsonDecode(map['json_data'])))
        .toList();
  }

  Future<OrdemServico?> getOrdemServicoById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ordens_servico',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return OrdemServico.fromJson(jsonDecode(maps.first['json_data']));
    }
    return null;
  }

  // MÉTODOS PARA AÇÕES PENDENTES
  Future<void> addPendingAction(
    int osId,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final db = await database;
    await db.insert('pending_actions', {
      'os_id': osId,
      'action': action,
      'payload': jsonEncode(payload),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    return await db.query('pending_actions', orderBy: 'timestamp ASC');
  }

  Future<List<Map<String, dynamic>>> getPendingActionsForOs(int osId) async {
    final db = await database;
    return await db.query(
      'pending_actions',
      where: 'os_id = ?',
      whereArgs: [osId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> deletePendingAction(int id) async {
    final db = await database;
    await db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
  }

  // MÉTODOS PARA MODIFICAR O CACHE OFFLINE
  Future<void> addDespesaToCache(int osId, Despesa despesa) async {
    final db = await database;
    final existingOs = await getOrdemServicoById(osId);
    if (existingOs != null) {
      existingOs.despesas.add(despesa);
      await cacheOrdemServicoDetalhes(existingOs);
    }
  }

  Future<void> addDocumentoToCache(int osId, DocumentoOS documento) async {
    final db = await database;
    final existingOs = await getOrdemServicoById(osId);
    if (existingOs != null) {
      existingOs.documentos.add(documento);
      await cacheOrdemServicoDetalhes(existingOs);
    }
  }

  // MÉTODOS DE CACHE PARA PONTOS (exemplo, não estava no seu helper)
  Future<void> cachePontos(List<RegistroPonto> pontos, int osId) async {
    final os = await getOrdemServicoById(osId);
    if (os != null) {
      // Cria uma cópia da OS, atualizando apenas a lista de pontos
      final osAtualizada = os.copyWith(pontos: pontos);
      // Salva o objeto OS completo de volta no banco de dados
      await cacheOrdemServicoDetalhes(osAtualizada);
      print("Pontos da OS $osId foram salvos no cache.");
    } else {
      print(
        "Aviso: OS $osId não encontrada no cache. Não foi possível salvar os pontos.",
      );
    }
  }

  Future<List<RegistroPonto>> getPontosFromCache(int osId) async {
    final os = await getOrdemServicoById(osId);
    // Se a OS existir no cache, retorna a lista de pontos dela.
    // Se não, retorna uma lista vazia.
    return os?.pontos ?? [];
  }

  Future<void> clearOsCache(int osId) async {
    final db = await database;
    await db.delete('ordens_servico', where: 'id = ?', whereArgs: [osId]);
  }

  Future<List<int>> getDistinctOsIdsFromPendingActions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pending_actions',
      distinct: true,
      columns: ['os_id'],
    );
    if (maps.isEmpty) {
      return [];
    }
    return maps.map((map) => map['os_id'] as int).toList();
  }

  /// Limpa todas as tabelas que contêm dados específicos do usuário.
  /// Essencial para ser chamado durante o logout.
  Future<void> clearAllUserData() async {
    final db = await database;
    print("Iniciando limpeza completa do cache do usuário...");
    await db.transaction((txn) async {
      // 1. Deleta todas as ordens de serviço cacheadas
      await txn.delete('ordens_servico');

      // 2. Deleta todas as ações pendentes que pertenciam ao usuário anterior
      await txn.delete('pending_actions');
    });
    print("Cache do banco de dados limpo com sucesso.");
  }

  /// Adiciona um novo relatório ao cache de uma Ordem de Serviço existente.
  Future<void> addRelatorioToCache(int osId, RelatorioCampo relatorio) async {
    final osDoCache = await getOrdemServicoById(osId);
    if (osDoCache != null) {
      // Cria uma nova lista de relatórios, adicionando o novo
      final relatoriosAtualizados =
          List<RelatorioCampo>.from(osDoCache.relatorios);
      relatoriosAtualizados.insert(
          0, relatorio); // Insere no início para aparecer primeiro

      // Cria uma cópia da OS com a lista de relatórios atualizada
      final osAtualizada =
          osDoCache.copyWith(relatorios: relatoriosAtualizados);

      // Salva a OS atualizada de volta no cache
      await cacheOrdemServicoDetalhes(osAtualizada);
      print("Relatório offline adicionado ao cache da OS $osId.");
    }
  }

  /// Verifica no cache local se já existe um relatório de um determinado tipo para uma data específica.
  Future<bool> checkIfReportExists(
      int osId, int tipoRelatorioId, DateTime data) async {
    final osDoCache = await getOrdemServicoById(osId);
    if (osDoCache == null) {
      return false; // Se a OS não está no cache, não há como haver relatórios
    }

    // Formata a data para comparar apenas o dia, ignorando as horas
    final dataParaVerificar = DateUtils.dateOnly(data);

    // Usa 'any' para verificar se algum relatório na lista satisfaz a condição
    final existe = osDoCache.relatorios.any((relatorio) {
      final dataDoRelatorioNoCache =
          DateUtils.dateOnly(relatorio.dataRelatorio);
      return relatorio.tipoRelatorio.id == tipoRelatorioId &&
          dataDoRelatorioNoCache == dataParaVerificar;
    });

    return existe;
  }
  // --- FIM DA ADIÇÃO ---
}
