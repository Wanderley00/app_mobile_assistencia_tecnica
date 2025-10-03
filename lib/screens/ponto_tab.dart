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
import '../models/ordem_servico.dart';

class PontoTab extends StatefulWidget {
  final OrdemServico os;
  final VoidCallback onDataChanged;

  const PontoTab({
    super.key,
    required this.os,
    required this.onDataChanged,
  });

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

      List<RegistroPonto> pontosBase;
      if (isOnline) {
        pontosBase = await _osRepository.getPontos(widget.os.id);
      } else {
        pontosBase = await _dbHelper.getPontosFromCache(widget.os.id);
      }

      final pendingActions =
          await _dbHelper.getPendingActionsForOs(widget.os.id);

      final List<RegistroPonto> pontosPendentesNovos = [];
      final Map<int, Map<String, dynamic>> saidasPendentes = {};

      for (var action in pendingActions) {
        final payload = jsonDecode(action['payload'] as String);

        if (action['action'] == 'register_ponto_entrada') {
          pontosPendentesNovos.add(
            RegistroPonto(
              id: -(action['id'] as int),
              tecnico: _usuarioLogado,
              data: DateTime.parse(payload['data']),
              // --- CORREÇÃO 1: Passando a String diretamente ---
              horaEntrada: payload['hora_entrada'],
              observacoes: payload['observacoes_entrada'],
              isPending: true,
            ),
          );
        } else if (action['action'] == 'register_ponto_saida') {
          final int pontoIdParaAtualizar = payload['ponto_id'];
          saidasPendentes[pontoIdParaAtualizar] = payload;
        }
      }

      List<RegistroPonto> pontosAtualizados = pontosBase.map((ponto) {
        if (saidasPendentes.containsKey(ponto.id)) {
          final payloadSaida = saidasPendentes[ponto.id]!;
          return ponto.copyWith(
            // --- CORREÇÃO 2: Passando a String diretamente ---
            horaSaida: payloadSaida['hora_saida'],
            observacoes: (ponto.observacoes ?? "") +
                "\nSaída (Offline): " +
                (payloadSaida['observacoes'] ?? ""),
            isPending: true,
          );
        }
        return ponto;
      }).toList();

      final todosOsPontos = [...pontosAtualizados, ...pontosPendentesNovos];

      if (mounted) {
        setState(() {
          _pontosDoUsuario = todosOsPontos;
          _pontoEmAbertoDoUsuario = _pontosDoUsuario.firstWhereOrNull(
            (p) => p.horaSaida == null && p.tecnico == _usuarioLogado,
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
          '/ordens-servico/${widget.os.id}/pontos/',
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
            // --- ADICIONE ESTA LINHA PARA AVISAR A TELA PAI ---
            widget.onDataChanged();
          }
        } else {
          final responseData = jsonDecode(utf8.decode(response.bodyBytes));
          throw Exception(responseData['detail'] ?? 'Falha ao marcar entrada.');
        }
      } else {
        await _dbHelper.addPendingAction(
          widget.os.id,
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
          // --- ADICIONE ESTA LINHA PARA AVISAR A TELA PAI ---
          widget.onDataChanged();
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
            // --- ADICIONE ESTA LINHA TAMBÉM AQUI ---
            widget.onDataChanged();
          }
        } else {
          throw Exception('Falha ao encerrar saída.');
        }
      } else {
        final offlinePayload = Map<String, dynamic>.from(payload)
          ..['ponto_id'] = _pontoEmAbertoDoUsuario!.id;

        await _dbHelper.addPendingAction(
          widget.os.id,
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
          // --- ADICIONE ESTA LINHA PARA AVISAR A TELA PAI ---
          widget.onDataChanged();
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

                            print('--- Renderizando Ponto ID: ${ponto.id} ---');
                            print(
                                'ponto.observacoesEntrada: "${ponto.observacoesEntrada}"');
                            print(
                                'ponto.observacoes (string completa): "${ponto.observacoes}"');

                            // --- LÓGICA DE EXIBIÇÃO CORRIGIDA ---
                            final obsEntrada = ponto.observacoesEntrada;
                            final obsSaida = ponto.observacoes;

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
      floatingActionButton:
          (widget.os.status == 'EM_EXECUCAO' || widget.os.status == 'REPROVADA')
              ? FloatingActionButton.extended(
                  onPressed: _isLoading
                      ? null
                      : () => _showPontoDialog(
                            isEntrada: _pontoEmAbertoDoUsuario == null,
                          ),
                  label: Text(_pontoEmAbertoDoUsuario != null
                      ? 'Marcar Saída'
                      : 'Marcar Entrada'),
                  icon: Icon(_pontoEmAbertoDoUsuario != null
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline),
                  backgroundColor: _pontoEmAbertoDoUsuario != null
                      ? AppColors.warning
                      : AppColors.success,
                )
              : null, // Se o status não permitir, o botão não aparece
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
