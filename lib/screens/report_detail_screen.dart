// lib/screens/report_detail_screen.dart (VERSÃO FINAL)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/relatorio_campo.dart';
import '../main.dart';
import '../widgets/info_row.dart';
import '../os_repository.dart'; // Import necessário

class ReportDetailScreen extends StatefulWidget {
  final int relatorioId;
  const ReportDetailScreen({super.key, required this.relatorioId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // --- VERIFIQUE SE ESTA LINHA ESTÁ AQUI ---
  final _osRepository = OsRepository();

  RelatorioCampo? _relatorio;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReportDetails();
  }

  Future<void> _fetchReportDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Esta chamada agora deve funcionar corretamente
      final relatorioData =
          await _osRepository.getRelatorioDetalhes(widget.relatorioId);
      if (mounted) {
        setState(() {
          _relatorio = relatorioData;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_relatorio?.tipoRelatorio.nome ?? 'Carregando...'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Erro: $_errorMessage'))
              : _relatorio == null
                  ? const Center(child: Text('Relatório não encontrado.'))
                  : RefreshIndicator(
                      onRefresh: _fetchReportDetails,
                      child: _buildReportContent(),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context)
              .pushNamed('/photo_form', arguments: _relatorio!.id);
          if (result == true && mounted) {
            _fetchReportDetails(); // Recarrega os detalhes para mostrar a nova foto
          }
        },
        label: const Text('Adicionar Foto'),
        icon: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }

  Widget _buildReportContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(title: 'Informações Gerais', children: [
            InfoRow(
                icon: Icons.calendar_today,
                text:
                    'Data: ${DateFormat('dd/MM/yyyy').format(_relatorio!.dataRelatorio)}'),
            InfoRow(
                icon: Icons.person, text: 'Executante: ${_relatorio!.tecnico}'),
            const Divider(height: 24),
            Text('Descrição das Atividades', style: AppTextStyles.subtitle1),
            const SizedBox(height: 8),
            Text(_relatorio!.descricaoAtividades, style: AppTextStyles.body2),
          ]),

          _buildCard(title: 'Materiais e Observações', children: [
            Text('Materiais/Peças Utilizadas', style: AppTextStyles.subtitle1),
            const SizedBox(height: 8),
            Text(_relatorio!.materialUtilizado ?? 'Nenhum material registrado.',
                style: AppTextStyles.body2),
            const Divider(height: 24),
            Text('Observações Adicionais', style: AppTextStyles.subtitle1),
            const SizedBox(height: 8),
            Text(
                _relatorio!.observacoesAdicionais ??
                    'Nenhuma observação adicional.',
                style: AppTextStyles.body2),
          ]),

          if (_relatorio!.problemas.isNotEmpty)
            _buildCard(
              title: 'Problemas e Soluções',
              isInitiallyExpanded: true,
              children: _relatorio!.problemas
                  .map((problema) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Problema: ${problema.categoria} / ${problema.subcategoria ?? ""}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Observação: ${problema.observacao ?? "N/A"}'),
                            Text(
                                'Solução: ${problema.solucaoAplicada ?? "N/A"}',
                                style: const TextStyle(
                                    color: AppColors.secondary)),
                          ],
                        ),
                      ))
                  .toList(),
            ),

          if (_relatorio!.horas.isNotEmpty)
            _buildCard(
              title: 'Dados de Horas e Deslocamento',
              children: _relatorio!.horas.map((hora) {
                // Para cada registo de hora, criamos um bloco vertical
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha 1: Nome do Técnico
                      Text(
                        hora.tecnico,
                        style: AppTextStyles.subtitle1.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      // Linha 2: Uma linha com as horas bem espaçadas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHourInfo('Normais', hora.horasNormaisHHMM),
                          _buildHourInfo('Extras 50%', hora.horasExtras60HHMM),
                          _buildHourInfo(
                              'Extras 100%', hora.horasExtras100HHMM),
                          _buildHourInfo(
                              'KM Rodado', hora.kmRodado.toStringAsFixed(1)),
                        ],
                      ),
                      // Adiciona uma linha divisória se não for o último item
                      if (_relatorio!.horas.last != hora)
                        const Divider(height: 20),
                    ],
                  ),
                );
              }).toList(),
            ),

          // Secção de Fotos (já corrigida)
          const SizedBox(height: 24),
          Text('Fotos do Relatório',
              style: AppTextStyles.headline2.copyWith(fontSize: 20)),
          const Divider(),
          _relatorio!.fotos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                      child: Text('Nenhuma foto adicionada a este relatório.')),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _relatorio!.fotos.length,
                  itemBuilder: (context, index) {
                    final foto = _relatorio!.fotos[index];

                    // --- INÍCIO DA CORREÇÃO DEFINITIVA ---
                    Widget imageWidget;

                    // 1. Verifica se existe um caminho para um ficheiro local.
                    if (foto.localFilePath != null &&
                        foto.localFilePath!.isNotEmpty) {
                      // Se existir, usa Image.file para carregar a imagem do armazenamento do dispositivo.
                      imageWidget = Image.file(File(foto.localFilePath!),
                          fit: BoxFit.cover);
                    }
                    // 2. Se não houver ficheiro local, verifica se existe uma URL da internet.
                    else if (foto.imagemUrl != null &&
                        foto.imagemUrl!.isNotEmpty) {
                      // Se existir, usa Image.network para carregar a imagem da rede.
                      imageWidget =
                          Image.network(foto.imagemUrl!, fit: BoxFit.cover);
                    }
                    // 3. Se não houver nem ficheiro local nem URL, mostra um ícone de imagem não encontrada.
                    else {
                      imageWidget = const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            size: 60, color: Colors.grey),
                      );
                    }
                    // --- FIM DA CORREÇÃO DEFINITIVA ---

                    return Card(
                      margin: const EdgeInsets.only(top: 12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // O AspectRatio garante que todas as pré-visualizações tenham a mesma proporção.
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child:
                                imageWidget, // Usa o widget de imagem que definimos acima.
                          ),
                          if (foto.descricao.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(foto.descricao,
                                  style: AppTextStyles.caption),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // Widget auxiliar para criar os cards padronizados
  Widget _buildCard(
      {required String title,
      required List<Widget> children,
      bool isInitiallyExpanded = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(title, style: AppTextStyles.subtitle1),
        initiallyExpanded: isInitiallyExpanded,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...children
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHourInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(value,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
