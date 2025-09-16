// lib/screens/ponto_tab.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import '../database_helper.dart';
import '../os_repository.dart';
import '../main.dart';
import '../models/registro_ponto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';

class PontoTab extends StatefulWidget {
  final int osId;
  const PontoTab({super.key, required this.osId});

  @override
  State<PontoTab> createState() => _PontoTabState();
}

class _PontoTabState extends State<PontoTab> {
  final OsRepository _osRepository = OsRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- ADIÇÃO DA INSTÂNCIA DO API CLIENT ---
  final ApiClient _apiClient = ApiClient(API_BASE_URL);
  // --- FIM DA ADIÇÃO ---

  List<RegistroPonto> _pontosDoUsuario = [];
  bool _isLoading = true;
  String? _errorMessage;
  RegistroPonto? _pontoEmAbertoDoUsuario;
  String _usuarioLogado = '';

  @override
  void initState() {
    super.initState();
    _fetchPontos();
  }

  Future<void> _getUsuarioLogado() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _usuarioLogado = prefs.getString('username') ?? '';
      });
    }
  }

  Future<void> _fetchPontos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _getUsuarioLogado();

    try {
      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOnline = connectivityResult != ConnectivityResult.none;

      // 1. Busca os pontos base (da API se online, do cache se offline)
      List<RegistroPonto> pontosBase;
      if (isOnline) {
        // Se online, busca da API e o repositório já atualiza o cache
        pontosBase = await _osRepository.getPontos(widget.osId);
      } else {
        // Se offline, busca diretamente do cache
        pontosBase = await _dbHelper.getPontosFromCache(widget.osId);
      }

      // 2. Busca TODAS as ações pendentes para esta OS
      final pendingActions =
          await _dbHelper.getPendingActionsForOs(widget.osId);

      final List<RegistroPonto> pontosPendentesNovos = [];
      // Mapa para armazenar as atualizações de saída pendentes, com chave sendo o ID do ponto
      final Map<int, Map<String, dynamic>> saidasPendentes = {};

      for (var action in pendingActions) {
        final payload = jsonDecode(action['payload']);

        if (action['action'] == 'register_ponto_entrada') {
          // Lógica existente para criar um novo ponto pendente de entrada
          pontosPendentesNovos.add(
            RegistroPonto(
              id: -action[
                  'id'], // ID negativo para indicar que é um item local pendente
              tecnico: _usuarioLogado,
              data: DateTime.parse(payload['data']),
              horaEntrada: payload['hora_entrada'],
              observacoes: payload['observacoes_entrada'],
              isPending: true,
            ),
          );
        } else if (action['action'] == 'register_ponto_saida') {
          // NOVA LÓGICA: Armazena os dados da ação de saída pendente
          // A chave do mapa é o 'ponto_id' que precisa ser atualizado
          final int pontoIdParaAtualizar = payload['ponto_id'];
          saidasPendentes[pontoIdParaAtualizar] = payload;
        }
      }

      // 3. Modifica a lista de pontos base com os dados das saídas pendentes
      List<RegistroPonto> pontosAtualizados = pontosBase.map((ponto) {
        // Verifica se existe uma saída pendente registrada para este ponto
        if (saidasPendentes.containsKey(ponto.id)) {
          final payloadSaida = saidasPendentes[ponto.id]!;
          // Retorna uma CÓPIA do objeto ponto, mas com os dados da saída offline
          return ponto.copyWith(
            horaSaida: payloadSaida['hora_saida'],
            // Concatena as observações para não perder a de entrada
            observacoes: (ponto.observacoes ?? "") +
                "\nSaída (Offline): " +
                (payloadSaida['observacoes'] ?? ""),
            isPending:
                true, // Marca o ponto como tendo uma ação pendente para sincronização
          );
        }
        // Se não houver saída pendente, retorna o ponto original
        return ponto;
      }).toList();

      // 4. Junta a lista de pontos (já modificada com saídas offline) com as novas entradas pendentes
      final todosOsPontos = [...pontosAtualizados, ...pontosPendentesNovos];

      // Filtra todos os pontos (sincronizados, modificados, novos) para o usuário logado
      final pontosFiltrados =
          todosOsPontos.where((p) => p.tecnico == _usuarioLogado).toList();

      if (mounted) {
        setState(() {
          _pontosDoUsuario = pontosFiltrados;
          // Recalcula qual é o ponto em aberto após aplicar todas as lógicas offline
          _pontoEmAbertoDoUsuario = _pontosDoUsuario.firstWhereOrNull(
            (p) => p.horaSaida == null,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ... (O restante do arquivo permanece o mesmo)
  Future<String> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Serviços de localização estão desativados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permissão de localização negada.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permissão de localização negada permanentemente.');
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return "${position.latitude}, ${position.longitude}";
    } catch (e) {
      return "Não foi possível obter a localização";
    }
  }

  Future<void> _showPontoDialog({bool isEntrada = true}) async {
    final observacaoController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEntrada ? 'Marcar Ponto de Entrada' : 'Encerrar Ponto de Saída',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Deseja ${isEntrada ? "marcar seu ponto de entrada" : "encerrar seu ponto de saída"} agora?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: observacaoController,
              decoration: const InputDecoration(
                labelText: 'Observações (Opcional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isEntrada ? AppColors.success : AppColors.warning,
            ),
            child: Text(isEntrada ? 'Marcar Entrada' : 'Encerrar Saída'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (isEntrada) {
        _marcarEntrada(observacaoController.text);
      } else {
        _encerrarSaida(observacaoController.text);
      }
    }
  }

  Future<void> _marcarEntrada(String observacao) async {
    setState(() => _isLoading = true);
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    try {
      final location = await _getCurrentLocation();
      final now = DateTime.now();
      final dataFormatada = DateFormat('yyyy-MM-dd').format(now);
      final horaFormatada = DateFormat('HH:mm:ss').format(now);

      final payload = {
        'data': dataFormatada,
        'hora_entrada': horaFormatada,
        'observacoes_entrada': observacao,
        'localizacao': location,
      };

      if (isOnline) {
        // --- CÓDIGO ANTIGO (SERÁ REMOVIDO) ---
        // final prefs = await SharedPreferences.getInstance();
        // final token = prefs.getString('authToken');
        // final response = await http.post(...);

        // --- CÓDIGO NOVO ---
        final response = await _apiClient.post(
          '/ordens-servico/${widget.osId}/pontos/',
          payload,
        );
        // --- FIM DO CÓDIGO NOVO ---

        if (response.statusCode == 201) {
          _fetchPontos();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ponto de entrada marcado com sucesso!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          throw Exception(responseData['detail'] ?? 'Falha ao marcar entrada.');
        }
      } else {
        await _dbHelper.addPendingAction(
          widget.osId,
          'register_ponto_entrada',
          payload,
        );
        _fetchPontos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ponto marcado offline. Será sincronizado quando a internet for restabelecida.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _encerrarSaida(String observacao) async {
    if (_pontoEmAbertoDoUsuario == null) return;
    setState(() => _isLoading = true);
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    try {
      final location = await _getCurrentLocation();
      final horaFormatada = DateFormat('HH:mm:ss').format(DateTime.now());

      final payload = {
        'hora_saida': horaFormatada,
        'observacoes': observacao,
        'localizacao_saida': location,
      };

      if (isOnline) {
        // --- CÓDIGO ANTIGO (SERÁ REMOVIDO) ---
        // final prefs = await SharedPreferences.getInstance();
        // final token = prefs.getString('authToken');
        // final response = await http.patch(...);

        // --- CÓDIGO NOVO ---
        final response = await _apiClient.patch(
          '/pontos/${_pontoEmAbertoDoUsuario!.id}/',
          payload,
        );
        // --- FIM DO CÓDIGO NOVO ---

        if (response.statusCode == 200) {
          _fetchPontos();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ponto de saída encerrado com sucesso!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          throw Exception('Falha ao encerrar saída.');
        }
      } else {
        final offlinePayload = Map<String, dynamic>.from(payload)
          ..['ponto_id'] = _pontoEmAbertoDoUsuario!.id;

        await _dbHelper.addPendingAction(
          widget.osId,
          'register_ponto_saida',
          offlinePayload,
        );
        _fetchPontos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ponto de saída encerrado offline. Será sincronizado quando a internet for restabelecida.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Erro: $_errorMessage'))
              : RefreshIndicator(
                  onRefresh: _fetchPontos,
                  child: _pontosDoUsuario.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum registro de ponto para este usuário na OS.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pontosDoUsuario.length,
                          itemBuilder: (context, index) {
                            final ponto = _pontosDoUsuario[index];

                            // --- LÓGICA DE EXIBIÇÃO CORRIGIDA ---
                            // Extrai as observações de entrada e saída
                            final obsEntrada = ponto.observacoesEntrada ??
                                ponto.observacoes
                                    ?.split('Saída:')[0]
                                    .replaceFirst('Entrada:', '')
                                    .trim();

                            final obsSaida = ponto.horaSaida != null &&
                                    ponto.observacoes?.contains('Saída:') ==
                                        true
                                ? ponto.observacoes!.split('Saída:')[1].trim()
                                : null;
                            // --- FIM DA LÓGICA DE EXIBIÇÃO ---

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row do Título (Técnico e Data) - Sem alterações
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (ponto.isPending)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(right: 8.0),
                                            child: Icon(Icons.sync_problem,
                                                color: AppColors.warning,
                                                size: 20),
                                          ),
                                        Expanded(
                                          child: Text(ponto.tecnico,
                                              style: AppTextStyles.subtitle1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        Text(
                                            DateFormat('dd/MM/yyyy')
                                                .format(ponto.data),
                                            style: AppTextStyles.caption),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    // Row de Informações (Entrada, Saída, Duração) - Sem alterações
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildPontoInfo(
                                            'Entrada',
                                            ponto.horaEntrada,
                                            Icons.login,
                                            AppColors.success),
                                        _buildPontoInfo(
                                            'Saída',
                                            ponto.horaSaida ?? 'Em Aberto',
                                            Icons.logout,
                                            ponto.horaSaida == null
                                                ? AppColors.warning
                                                : AppColors.error),
                                        _buildPontoInfo(
                                            'Duração',
                                            ponto.duracaoFormatada ?? '...',
                                            Icons.hourglass_empty,
                                            ponto.isPending
                                                ? AppColors.warning
                                                : AppColors.primary),
                                      ],
                                    ),
                                    // --- INÍCIO DA CORREÇÃO DE LAYOUT ---
                                    if (obsEntrada != null &&
                                            obsEntrada.isNotEmpty ||
                                        obsSaida != null &&
                                            obsSaida.isNotEmpty) ...[
                                      const Divider(height: 20),
                                      Text('Observações:',
                                          style: AppTextStyles.caption),
                                      const SizedBox(height: 8),

                                      // Exibe a observação de ENTRADA se existir
                                      if (obsEntrada != null &&
                                          obsEntrada.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4.0),
                                          child: Text("Entrada: $obsEntrada",
                                              style: AppTextStyles.body2),
                                        ),

                                      // Exibe a observação de SAÍDA se existir
                                      if (obsSaida != null &&
                                          obsSaida.isNotEmpty)
                                        Text("Saída: $obsSaida",
                                            style: AppTextStyles.body2),
                                    ]
                                    // --- FIM DA CORREÇÃO DE LAYOUT ---
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading
            ? null
            : () =>
                _showPontoDialog(isEntrada: _pontoEmAbertoDoUsuario == null),
        label: Text(_pontoEmAbertoDoUsuario == null
            ? 'Marcar Entrada'
            : 'Encerrar Saída'),
        icon:
            Icon(_pontoEmAbertoDoUsuario == null ? Icons.login : Icons.logout),
        backgroundColor: _pontoEmAbertoDoUsuario == null
            ? AppColors.success
            : AppColors.warning,
      ),
    );
  }

  Widget _buildPontoInfo(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.subtitle1.copyWith(color: color)),
      ],
    );
  }
}
