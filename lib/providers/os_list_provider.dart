// lib/providers/os_list_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ordem_servico.dart';
import '../os_repository.dart';
import '../sync_service.dart';
import '../main.dart'; // Para o navigatorKey
import '../utils/error_handler.dart';
import '../api_client.dart';
import '../database_helper.dart';

class OsListProvider with ChangeNotifier {
  // DEPENDÊNCIAS
  final OsRepository _repository = OsRepository();
  final SyncService _syncService = SyncService();

  // --- ALTERAÇÃO 1: Substituir isLoading por estados específicos ---
  // A variável _isLoading foi removida.
  bool _isDownloading = false;
  bool _isSyncing = false;
  // --- FIM DA ALTERAÇÃO 1 ---

  String _activeStatusFilter = 'Em andamento'; // Filtro padrão
  String _currentSearchQuery = ''; // Para guardar o texto da busca

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

  // --- ALTERAÇÃO 2: Adicionar getters para os novos estados ---
  bool get isDownloading => _isDownloading;
  bool get isSyncing => _isSyncing;
  // Um getter geral para saber se qualquer ação está em andamento.
  bool get isBusy => _isDownloading || _isSyncing;
  // --- ADIÇÃO: Expor o status da conexão para a UI ---
  bool get isOnline => _isOnline;
  // --- FIM DA ALTERAÇÃO 2 ---

  // CONSTRUTOR
  OsListProvider() {
    //_initialize();
  }

  Future<void> initialize() async {
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
    _applyFilters(); // Re-aplica os filtros com o novo status
  }

  void _applyFilters() {
    List<OrdemServico> results = List.from(_ordensServico);

    // Etapa 1: Filtrar por Status
    if (_activeStatusFilter == 'Em andamento') {
      // Considera-se "Em andamento" qualquer status que não seja "CONCLUIDA"
      // Adapte esta lista se tiver outros status finais como "CANCELADA"
      results = results
          .where((os) => os.status.toUpperCase() != 'CONCLUIDA')
          .toList();
    } else if (_activeStatusFilter == 'Concluída') {
      results = results
          .where((os) => os.status.toUpperCase() == 'CONCLUIDA')
          .toList();
    }

    // Etapa 2: Filtrar pelo texto da busca (sobre o resultado do filtro de status)
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

  Future<void> _loadUserData() async {
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

        // --- LÓGICA ADICIONADA AQUI ---
        if (isNowOnline) {
          // Se o app acabou de ficar online:
          // 1. Mostra uma mensagem de sucesso para o usuário.
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
              duration: Duration(seconds: 3), // Mensagem rápida
            ));
          }
          // 2. Inicia a sincronização dos dados pendentes.
          syncAllChanges();
        }
        // --- FIM DA LÓGICA ADICIONADA ---

        notifyListeners();
      }
    });
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> loadOrdensFromCache() async {
    try {
      // 1. Pega a lista de OS base do cache
      final ordensBase = await _repository.getOrdensServicoFromCache();

      // --- LÓGICA ADICIONADA ---
      // 2. Cria uma nova lista que será preenchida
      final List<OrdemServico> ordensComStatusPendente = [];

      // 3. Itera sobre a lista base para verificar cada OS
      for (final os in ordensBase) {
        final pendingActions = await _dbHelper.getPendingActionsForOs(os.id);

        // 4. Cria uma cópia da OS, atualizando a propriedade hasPendingActions
        ordensComStatusPendente
            .add(os.copyWith(hasPendingActions: pendingActions.isNotEmpty));
      }
      // --- FIM DA LÓGICA ADICIONADA ---

      // 5. Atualiza o estado do provider com a nova lista, que agora contém a informação de pendência
      _ordensServico = ordensComStatusPendente;
      _applyFilters(); // Em vez de popular _filteredOrdensServico diretamente, aplicamos os filtros
    } catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    } finally {
      notifyListeners(); // O notifyListeners do _applyFilters já atualiza a UI
    }
  }

  Future<void> fetchAllAndCache() async {
    if (_isDownloading) return; // Alteração do seu arquivo original mantida
    _isDownloading = true;
    notifyListeners();
    try {
      await _repository.fetchAllAndCache();
      await loadOrdensFromCache();
      _errorMessage = null;
      // --- ALTERAÇÃO AQUI ---
    } on UnauthorizedException catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      // Se a sessão expirou, chama o logout.
      // O Future.microtask garante que isso aconteça sem conflito com o build da UI.
      Future.microtask(() => logout());
      // --- FIM DA ALTERAÇÃO ---
    } catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> syncAllChanges() async {
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
      // --- FIM DA ALTERAÇÃO ---
    } catch (e) {
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    } finally {
      await loadOrdensFromCache();
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // --- LÓGICA DE LOGOUT APRIMORADA ---

    // 1. Limpa o cache do banco de dados local (SQLite)
    // Esta é a etapa mais importante para remover os dados do usuário anterior.
    await _dbHelper.clearAllUserData();

    // 2. Reseta o estado do provider em memória
    // Isso garante que a lista na tela fique vazia imediatamente.
    _ordensServico = [];
    _filteredOrdensServico = [];
    _username = 'Usuário';
    notifyListeners(); // Notifica a UI para remover os itens da lista

    // 3. Limpa os dados da sessão (tokens, etc.) do SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 4. Redireciona para a tela de login, removendo todas as telas anteriores da pilha
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
    // --- FIM DA LÓGICA APRIMORADA ---
  }

  // O método _setLoading foi removido pois não é mais necessário.

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  /// Encapsula a chamada ao serviço para verificar se há ações pendentes.
  Future<bool> hasPendingActions() async {
    return await _syncService.hasPendingActions();
  }
}
