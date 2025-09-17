// lib/providers/os_list_provider.dart - VERSÃO CORRIGIDA

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ordem_servico.dart';
import '../os_repository.dart';
import '../sync_service.dart';
import '../main.dart';
import '../utils/error_handler.dart';
import '../api_client.dart';
import '../database_helper.dart';
import '../auth_helper.dart';

class OsListProvider with ChangeNotifier {
  final OsRepository _repository = OsRepository();
  final SyncService _syncService = SyncService();

  bool _isDownloading = false;
  bool _isSyncing = false;
  String _activeStatusFilter = 'Em andamento';
  String _currentSearchQuery = '';
  List<OrdemServico> _ordensServico = [];
  List<OrdemServico> _filteredOrdensServico = [];
  String? _errorMessage;
  String _username = 'Usuário';
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  DateTime _lastInteractionTime = DateTime.now();

  // GETTERS
  List<OrdemServico> get filteredOrdensServico => _filteredOrdensServico;
  String? get errorMessage => _errorMessage;
  String get username => _username;
  DateTime get lastInteractionTime => _lastInteractionTime;
  String get activeStatusFilter => _activeStatusFilter;
  bool get isDownloading => _isDownloading;
  bool get isSyncing => _isSyncing;
  bool get isBusy => _isDownloading || _isSyncing;
  bool get isOnline => _isOnline;

  OsListProvider() {
    // Inicialização será feita via initialize()
  }

  Future initialize() async {
    await _loadUserData();
    await loadOrdensFromCache();
    _setupConnectivityListener();
    await syncAllChanges();
  }

  void filterOrdens(String query) {
    _currentSearchQuery = query;
    _applyFilters();
  }

  void setActiveStatusFilter(String status) {
    _activeStatusFilter = status;
    _applyFilters();
  }

  void _applyFilters() {
    List<OrdemServico> results = List.from(_ordensServico);

    if (_activeStatusFilter == 'Em andamento') {
      results = results
          .where((os) => os.status.toUpperCase() != 'CONCLUIDA')
          .toList();
    } else if (_activeStatusFilter == 'Concluída') {
      results = results
          .where((os) => os.status.toUpperCase() == 'CONCLUIDA')
          .toList();
    }

    if (_currentSearchQuery.isNotEmpty) {
      final lowerCaseQuery = _currentSearchQuery.toLowerCase();
      results = results.where((os) {
        return os.numeroOs.toLowerCase().contains(lowerCaseQuery) ||
            os.tituloServico.toLowerCase().contains(lowerCaseQuery) ||
            os.cliente.razaoSocial.toLowerCase().contains(lowerCaseQuery) ||
            os.equipamento.nome.toLowerCase().contains(lowerCaseQuery);
      }).toList();
    }

    _filteredOrdensServico = results;
    notifyListeners();
  }

  void updateInteractionTime() {
    _lastInteractionTime = DateTime.now();
  }

  Future _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? 'Usuário';
    notifyListeners();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final bool isNowOnline = result != ConnectivityResult.none;
      if (isNowOnline != _isOnline) {
        _isOnline = isNowOnline;

        if (isNowOnline) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Você está online.'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ));
          }

          syncAllChanges();
        }

        notifyListeners();
      }
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future loadOrdensFromCache() async {
    try {
      final ordensBase = await _repository.getOrdensServicoFromCache();
      final List<OrdemServico> ordensComStatusPendente = [];

      for (final os in ordensBase) {
        final pendingActions = await _dbHelper.getPendingActionsForOs(os.id);
        ordensComStatusPendente
            .add(os.copyWith(hasPendingActions: pendingActions.isNotEmpty));
      }

      _ordensServico = ordensComStatusPendente;
      _applyFilters();
    } catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    } finally {
      notifyListeners();
    }
  }

  Future fetchAllAndCache() async {
    if (_isDownloading) return;
    _isDownloading = true;
    notifyListeners();

    try {
      await _repository.fetchAllAndCache();
      await loadOrdensFromCache();
      _errorMessage = null;
    } on UnauthorizedException catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      Future.microtask(() => logout());
    } catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future syncAllChanges() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    _errorMessage = null;

    final List<int> osIdsToUpdate =
        await _syncService.getDistinctOsIdsFromPendingActions();

    try {
      await _syncService.processSyncQueue();
      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline && osIdsToUpdate.isNotEmpty) {
        print("Atualizando cache para as OSs modificadas: $osIdsToUpdate");
        for (final osId in osIdsToUpdate) {
          try {
            await _repository.getOsDetalhes(osId);
          } catch (e) {
            print(
              "Não foi possível atualizar o cache para a OS $osId após o sync: $e",
            );
          }
        }
      }
    } on UnauthorizedException catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      Future.microtask(() => logout());
    } catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    } finally {
      await loadOrdensFromCache();
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future logout() async {
    // CORREÇÃO PRINCIPAL: Usar AuthHelper.logout() em vez de clearAllUserData()
    // Isso preserva o cache SQLite e remove apenas a sessão do usuário
    await AuthHelper.logout();

    // Resetar apenas o estado em memória do provider
    _ordensServico = [];
    _filteredOrdensServico = [];
    _username = 'Usuário';
    notifyListeners();

    // Navegar para a tela de login
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<bool> hasPendingActions() async {
    return await _syncService.hasPendingActions();
  }
}
