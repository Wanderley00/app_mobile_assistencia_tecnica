// lib/screens/os_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import '../os_repository.dart';
import '../main.dart';
import '../models/ordem_servico.dart';
import 'ponto_tab.dart';
import '../widgets/status_badge.dart';
import '../widgets/info_row.dart';
import 'dart:convert'; // Para corrigir o erro em 'jsonDecode'
import '../database_helper.dart'; // Para corrigir o erro em '_dbHelper'
import '../models/documento_os.dart'; // Para corrigir o erro em 'DocumentoOS'
import '../models/despesa.dart';
import 'expense_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/os_list_provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../api_client.dart';
import 'expense_form_screen.dart';
import 'document_form_screen.dart';
import '../models/tipo_documento.dart';
import '../models/relatorio_campo.dart';
import 'report_form_screen.dart';
import '../models/registro_ponto.dart';

class OsDetailScreen extends StatefulWidget {
  final int osId;
  final String osNumero;

  const OsDetailScreen({super.key, required this.osId, required this.osNumero});

  @override
  State<OsDetailScreen> createState() => _OsDetailScreenState();
}

class _OsDetailScreenState extends State<OsDetailScreen> {
  OrdemServico? _ordemServico;
  bool _isLoading = true;
  String? _errorMessage;
  final OsRepository _osRepository = OsRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  @override
  void initState() {
    super.initState();
    _fetchOsDetails();
  }

  Future<void> _fetchOsDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Etapa 1: Busca os detalhes base da OS (da API ou do cache)
      var os = await _osRepository.getOsDetalhes(widget.osId);

      // Etapa 2: Busca TODAS as ações pendentes para esta OS
      final pendingActions =
          await _dbHelper.getPendingActionsForOs(widget.osId);

      if (pendingActions.isNotEmpty) {
        final List<DocumentoOS> pendingDocuments = [];
        final List<Despesa> pendingExpenses = [];

        // Cópia das listas para podermos modificá-las com segurança
        List<Despesa> despesasAtualizadas = List<Despesa>.from(os.despesas);
        List<DocumentoOS> documentosAtualizados =
            List<DocumentoOS>.from(os.documentos);

        for (var action in pendingActions) {
          final payload = jsonDecode(action['payload'] as String);

          if (action['action'] == 'add_document') {
            pendingDocuments.add(
              DocumentoOS(
                id: action['id'] as int,
                titulo: payload['titulo'],
                tipoDocumento: TipoDocumento(id: 0, nome: 'Pendente'),
                dataUpload: DateTime.parse(action['timestamp'] as String),
                uploadedBy: 'Você (Offline)',
                isPending: true,
                localFilePath: payload['arquivo_caminho'],
              ),
            );
          } else if (action['action'] == 'create_expense') {
            pendingExpenses.add(
              Despesa(
                id: action['id'] as int,
                descricao: payload['descricao'],
                valor: double.tryParse(payload['valor'].toString()) ?? 0.0,
                dataDespesa: DateTime.parse(payload['data_despesa']),
                tecnico: 'Você (Offline)',
                isPending: true,
                // --- CORREÇÃO APLICADA AQUI ---
                // Adicionamos o ID da OS, que agora é obrigatório.
                ordemServicoId: widget.osId,
              ),
            );
          } else if (action['action'] == 'edit_expense') {
            final int despesaId = payload['despesa_id'];
            final int index =
                despesasAtualizadas.indexWhere((d) => d.id == despesaId);

            if (index != -1) {
              final despesaAntiga = despesasAtualizadas[index];
              final despesaAtualizada = Despesa(
                id: despesaId,
                descricao: payload['descricao'],
                valor: double.tryParse(payload['valor'].toString()) ?? 0.0,
                dataDespesa: DateTime.parse(payload['data_despesa']),
                tecnico: 'Você (Offline)',
                isPending: true,
                local: payload['local_despesa'],
                isAdiantamento: payload['is_adiantamento'],
                categoria: despesaAntiga.categoria,
                formaPagamento: despesaAntiga.formaPagamento,
                statusAprovacao: 'PENDENTE',
                aprovadoPor: null,
                dataAprovacao: null,
                comentarioAprovacao: null,
                // --- CORREÇÃO APLICADA AQUI ---
                // Adicionamos o ID da OS, que agora é obrigatório.
                ordemServicoId: widget.osId,
              );
              despesasAtualizadas[index] = despesaAtualizada;
            }
          } else if (action['action'] == 'edit_document') {
            final int docId = payload['documento_id'];
            final int index =
                documentosAtualizados.indexWhere((d) => d.id == docId);

            if (index != -1) {
              final docAntigo = documentosAtualizados[index];
              final docAtualizado = docAntigo.copyWith(
                titulo: payload['titulo'],
                isPending: true,
              );
              documentosAtualizados[index] = docAtualizado;
            }
          }
        }

        // Atualiza o objeto OS principal com as listas completas e modificadas
        os = os.copyWith(
          documentos: [...documentosAtualizados, ...pendingDocuments],
          despesas: [...despesasAtualizadas, ...pendingExpenses],
        );
      }

      if (mounted) {
        setState(() {
          _ordemServico = os;
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

  Future<void> _deleteDespesa(Despesa despesa) async {
    // 1. Pede confirmação ao usuário
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja deletar a despesa "${despesa.descricao}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Deletar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return; // Se o usuário cancelou, para aqui.

    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    try {
      if (isOnline) {
        // 2. Lógica Online: Chama a API para deletar
        final apiClient = ApiClient(API_BASE_URL);
        // Supondo que sua rota seja /api/despesas/<id>/
        final response = await apiClient.delete('/despesas/${despesa.id}/');
        if (response.statusCode != 204) {
          throw Exception('Falha ao deletar a despesa no servidor.');
        }
      } else {
        // 3. Lógica Offline: Adiciona uma ação pendente
        await _dbHelper.addPendingAction(
          widget.osId,
          'delete_expense',
          {'despesa_id': despesa.id},
        );
      }

      // 4. Atualiza a UI para refletir a exclusão
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Despesa "${despesa.descricao}" marcada para exclusão.'),
        backgroundColor: AppColors.success,
      ));
      // Recarrega os detalhes da OS para remover o item da lista
      await _fetchOsDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao deletar despesa: ${e.toString()}'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _deleteDocumento(DocumentoOS documento) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja deletar o documento "${documento.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Deletar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    try {
      if (isOnline) {
        final response =
            await _apiClient.delete('/documentos/${documento.id}/');
        if (response.statusCode != 204) {
          throw Exception('Falha ao deletar o documento no servidor.');
        }
      } else {
        await _dbHelper.addPendingAction(
          widget.osId,
          'delete_document',
          {'documento_id': documento.id},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Documento "${documento.titulo}" marcado para exclusão.'),
        backgroundColor: AppColors.success,
      ));
      await _fetchOsDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao deletar documento: ${e.toString()}'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final osProvider = context.watch<OsListProvider>();
    final isOnline = osProvider.isOnline;

    // Lógica para habilitar o botão de conclusão
    bool canConclude = false;
    if (_ordemServico != null &&
        _ordemServico!.status != 'CONCLUIDA' &&
        _ordemServico!.status != 'PENDENTE_APROVACAO') {
      final hasClosedPonto =
          _ordemServico!.pontos.any((p) => p.horaSaida != null);
      final hasRelatorio = _ordemServico!.relatorios.isNotEmpty;
      canConclude = isOnline && hasClosedPonto && hasRelatorio;
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.osNumero),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Tooltip(
                message: osProvider.isOnline ? 'Online' : 'Offline',
                child: Icon(
                  osProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: osProvider.isOnline
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Detalhes'),
              Tab(icon: Icon(Icons.timer_outlined), text: 'Ponto'),
              Tab(icon: Icon(Icons.description_outlined), text: 'Relatórios'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Despesas'),
              Tab(icon: Icon(Icons.attach_file_outlined), text: 'Documentos'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text('Erro: $_errorMessage'))
                : _ordemServico == null
                    ? const Center(child: Text('Nenhum dado encontrado.'))
                    : TabBarView(
                        children: [
                          RefreshIndicator(
                            onRefresh: _fetchOsDetails,
                            child: _buildDetailsTab(_ordemServico!),
                          ),
                          PontoTab(osId: widget.osId),
                          RefreshIndicator(
                            onRefresh: _fetchOsDetails,
                            child: _buildRelatoriosTab(_ordemServico!),
                          ),
                          RefreshIndicator(
                            onRefresh: _fetchOsDetails,
                            child: _buildDespesasTab(_ordemServico!),
                          ),
                          RefreshIndicator(
                            onRefresh: _fetchOsDetails,
                            child: _buildDocumentosTab(_ordemServico!),
                          ),
                        ],
                      ),
        // --- ADIÇÃO DO BOTÃO FLUTUANTE ---
        floatingActionButton: canConclude
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/conclusion_signature',
                    arguments: widget.osId,
                  );
                  // Se a tela de conclusão retornou 'true', recarrega os detalhes
                  if (result == true && mounted) {
                    await _fetchOsDetails();
                    // Avisa a tela de lista para atualizar o status da OS
                    context.read<OsListProvider>().syncAllChanges();
                  }
                },
                label: const Text('Concluir OS'),
                icon: const Icon(Icons.check_circle),
                backgroundColor: AppColors.success,
              )
            : null, // Se as condições não forem atendidas, o botão não aparece
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }

  Widget _buildDetailsTab(OrdemServico os) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 1. CARD PRINCIPAL - Este permanece igual, sempre visível.
          _buildDetailCard('Informações da Ordem de Serviço', [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoColumn('Número da OS:', os.numeroOs),
                      _buildInfoColumn(
                        'Tipo de Serviço:',
                        os.tipoManutencao ?? 'N/A',
                      ),
                      _buildInfoColumn('Cliente:', os.cliente.razaoSocial),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoColumn('Status:', os.status, status: os.status),
                      _buildInfoColumn(
                        'Equipamento:',
                        '${os.equipamento.nome} (${os.equipamento.modelo})',
                      ),
                      _buildInfoColumn(
                        'Responsável pela Obra:',
                        os.tecnicoResponsavel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoColumn('Título do Serviço:', os.tituloServico),
          ]),

          const SizedBox(height: 16),

          // --- INÍCIO DA ALTERAÇÃO 1: Convertendo o card de Descrição para ExpansionTile ---
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text('Descrição e Planejamento',
                  style: AppTextStyles.subtitle1),
              leading: const Icon(Icons.description_outlined),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    // --- CORREÇÃO APLICADA AQUI ---
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // --- FIM DA CORREÇÃO ---
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildInfoColumn(
                        'Descrição do Problema (Original da OS):',
                        os.descricaoProblema,
                      ),
                      _buildInfoColumn(
                        'Observações Gerais:',
                        os.observacoesGerais ?? 'Nenhuma.',
                      ),
                      const Divider(height: 24),
                      Text('Planejamento e Execução',
                          style: AppTextStyles.subtitle1),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfoColumn(
                              'Início Planejado:',
                              os.dataInicioPlanejado != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(os.dataInicioPlanejado!)
                                  : 'N/A',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoColumn(
                              'Início Real:',
                              os.dataInicioReal != null
                                  ? DateFormat('dd/MM/yyyy HH:mm')
                                      .format(os.dataInicioReal!.toLocal())
                                  : 'N/A',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildInfoColumn(
                              'Previsão de Conclusão:',
                              os.dataConclusaoPrevista != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(os.dataConclusaoPrevista!)
                                  : 'N/A',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoColumn(
                              'Conclusão Real:',
                              os.dataFechamento != null
                                  ? DateFormat('dd/MM/yyyy HH:mm')
                                      .format(os.dataFechamento!.toLocal())
                                  : 'N/A',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // --- FIM DA ALTERAÇÃO 1 ---

          const SizedBox(height: 16),

          // ExpansionTile de "Equipe de Apoio"
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text('Equipe de Apoio', style: AppTextStyles.subtitle1),
              leading: const Icon(Icons.people_outline),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: os.equipe.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Nenhum membro na equipe de apoio.'),
                        )
                      : Column(
                          // --- CORREÇÃO APLICADA AQUI ---
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          // --- FIM DA CORREÇÃO ---
                          children: os.equipe
                              .map((membro) => _buildInfoColumn(
                                    membro.usuario,
                                    membro.funcao ?? 'N/A',
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatoriosTab(OrdemServico os) {
    return Scaffold(
      body: os.relatorios.isEmpty
          ? const Center(child: Text('Nenhum relatório de campo registrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: os.relatorios.length,
              itemBuilder: (context, index) {
                final relatorio = os.relatorios[index];

                // --- ALTERAÇÃO FINAL AQUI ---
                // Em vez de construir o Card aqui, chamamos o método que criámos.
                return _buildRelatorioCard(relatorio);
                // --- FIM DA ALTERAÇÃO ---
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Esta lógica de recarregar a página ao voltar já está correta.
          final result = await Navigator.pushNamed(
            context,
            '/report_form',
            arguments: os.id,
          );
          if (result == true && mounted) {
            _fetchOsDetails();
          }
        },
        label: const Text('Novo Relatório'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // --- 1. ADICIONE ESTE NOVO MÉTODO COMPLETO ---
  Widget _buildDespesaCard(Despesa despesa) {
    final Color statusColor =
        despesa.isPending ? AppColors.warning : AppColors.primaryLight;
    IconData categoryIcon = Icons.receipt_long_outlined;
    if (despesa.categoria != null) {
      String categoriaNome = despesa.categoria!.nome.toLowerCase();
      if (categoriaNome.contains('aliment')) {
        categoryIcon = Icons.restaurant_outlined;
      } else if (categoriaNome.contains('transporte') ||
          categoriaNome.contains('combustível')) {
        categoryIcon = Icons.directions_car_outlined;
      } else if (categoriaNome.contains('hospedagem')) {
        categoryIcon = Icons.hotel_outlined;
      }
    }

    // Estrutura Padronizada
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Slidable(
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: (context) async {
                  final result =
                      await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ExpenseFormScreen(
                      ordemServicoId: widget.osId,
                      despesaParaEditar: despesa,
                    ),
                  ));
                  if (result == true && mounted) {
                    _fetchOsDetails();
                  }
                },
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Editar',
                // --- CORREÇÃO APLICADA AQUI ---
                // Adiciona o arredondamento que faltava no botão de editar.
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              SlidableAction(
                onPressed: (context) => _deleteDespesa(despesa),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Deletar',
                // O botão de deletar já estava correto.
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.1),
                child: Icon(categoryIcon, color: statusColor),
              ),
              title: Text(despesa.descricao,
                  style: AppTextStyles.subtitle1.copyWith(fontSize: 15)),
              subtitle: Text(
                '${despesa.tecnico} - ${DateFormat('dd/MM/yyyy').format(despesa.dataDespesa)}',
                style: AppTextStyles.caption,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${despesa.valor.toStringAsFixed(2)}',
                    style: AppTextStyles.subtitle1
                        .copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (despesa.statusAprovacao != null)
                        StatusBadge(status: despesa.statusAprovacao!),
                      if (despesa.statusAprovacao == 'APROVADA' &&
                          despesa.statusPagamento != null) ...[
                        const SizedBox(width: 4),
                        StatusBadge(status: despesa.statusPagamento!),
                      ],
                    ],
                  )
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ExpenseDetailScreen(despesa: despesa),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDespesasTab(OrdemServico os) {
    return Scaffold(
      body: os.despesas.isEmpty
          ? const Center(child: Text('Nenhuma despesa registrada.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: os.despesas.length,
              itemBuilder: (context, index) {
                final despesa = os.despesas[index];
                // Agora, simplesmente chamamos o nosso novo método para construir o card
                return _buildDespesaCard(despesa);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/expense_form',
            arguments: os.id,
          );
          if (result == true && mounted) {
            _fetchOsDetails();
          }
        },
        label: const Text('Nova Despesa'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  Widget _buildDocumentosTab(OrdemServico os) {
    return Scaffold(
      body: os.documentos.isEmpty
          ? const Center(child: Text('Nenhum documento anexado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: os.documentos.length,
              itemBuilder: (context, index) {
                final doc = os.documentos[index];
                final bool isLocal =
                    doc.localFilePath != null && doc.localFilePath!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(
                      bottom:
                          12.0), // Era 16.0, ajustado para 12.0 para padronizar
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Slidable(
                      endActionPane: ActionPane(
                        motion: const StretchMotion(),
                        children: [
                          // --- INÍCIO DA CORREÇÃO ---
                          // 1. Ação de Editar
                          SlidableAction(
                            onPressed: (context) async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DocumentFormScreen(
                                    ordemServicoId: widget.osId,
                                    documentoParaEditar: doc,
                                  ),
                                ),
                              );
                              if (result == true && mounted) {
                                _fetchOsDetails();
                              }
                            },
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            label: 'Editar',
                            // Arredonda apenas os cantos da ESQUERDA
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),

                          // 2. Ação de Deletar
                          SlidableAction(
                            onPressed: (context) {
                              _deleteDocumento(doc);
                            },
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Deletar',
                            // Arredonda apenas os cantos da DIREITA
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          // --- FIM DA CORREÇÃO ---
                        ],
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        child: ListTile(
                          leading: Icon(
                            doc.isPending
                                ? Icons.cloud_upload_outlined
                                : isLocal
                                    ? Icons.cloud_done_outlined
                                    : Icons.insert_drive_file_outlined,
                            color: doc.isPending
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                          title: Text(doc.titulo),
                          subtitle: Text(
                            '${doc.tipoDocumento.nome} - Enviado por ${doc.uploadedBy}',
                          ),
                          trailing: (isLocal ||
                                  (doc.arquivoUrl != null &&
                                      doc.arquivoUrl!.isNotEmpty))
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.open_in_new,
                                    color: AppColors.secondary,
                                  ),
                                  onPressed: () async {
                                    try {
                                      if (isLocal) {
                                        await OpenFile.open(doc.localFilePath!);
                                      } else if (doc.arquivoUrl != null) {
                                        final uri = Uri.parse(doc.arquivoUrl!);
                                        if (!await launchUrl(uri,
                                            mode: LaunchMode
                                                .externalApplication)) {
                                          throw Exception(
                                              'Não foi possível abrir o link.');
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Erro: ${e.toString()}'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/document_form',
            arguments: os.id,
          );
          if (result == true && mounted) {
            _fetchOsDetails();
          }
        },
        label: const Text('Novo Documento'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primaryLight,
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.subtitle1),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value, {String? status}) {
    Widget valueWidget = Text(
      value,
      style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
    );

    if (status != null) {
      valueWidget = StatusBadge(status: status);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          valueWidget,
        ],
      ),
    );
  }

  Widget _buildRelatorioCard(RelatorioCampo relatorio) {
    // A lógica para definir o ícone e a cor permanece a mesma
    final IconData iconData = relatorio.isPendingSync
        ? Icons.cloud_upload_outlined
        : Icons.description_outlined;
    final Color iconColor =
        relatorio.isPendingSync ? AppColors.warning : AppColors.primaryLight;
    final String statusText =
        relatorio.isPendingSync ? 'Pendente de sincronização' : 'Sincronizado';

    // --- ESTRUTURA PADRONIZADA ---
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Slidable(
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              // Ação de Editar
              SlidableAction(
                onPressed: (context) async {
                  final result =
                      await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ReportFormScreen(
                      ordemServicoId: widget.osId,
                      relatorioParaEditar: relatorio,
                    ),
                  ));

                  if (result == true && mounted) {
                    _fetchOsDetails();
                  }
                },
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                icon: Icons.edit,
                label: 'Editar',
                // Adiciona o border radius para combinar com a borda do ClipRRect
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: ListTile(
              leading: Icon(iconData, color: iconColor, size: 36),
              title: Text(
                relatorio.tipoRelatorio.nome,
                style: AppTextStyles.subtitle1,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(relatorio.dataRelatorio)} por ${relatorio.tecnico}',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    relatorio.descricaoAtividades,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () {
                Navigator.of(context).pushNamed(
                  '/report_detail',
                  arguments: relatorio.id,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
