// lib/screens/report_form_screen.dart

import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:signature/signature.dart';

import '../main.dart'; // Para AppColors, AppTextStyles e a URL da API
import '../database_helper.dart';
import '../models/tipo_relatorio.dart';
import '../models/horas_relatorio_tecnico.dart';
import '../api_client.dart';
import '../widgets/info_row.dart';

import '../os_repository.dart';
import '../models/categoria_problema.dart';
import '../models/subcategoria_problema.dart';

import '../models/relatorio_campo.dart';

// // Classe auxiliar para agrupar os dados que vêm da API
// class DadosCalculadosRelatorio {
//   final List<HorasRelatorioTecnico> horasCalculadas;

//   DadosCalculadosRelatorio({
//     required this.horasCalculadas,
//   });
// }

class ProblemaRelatorioFormModel {
  final TextEditingController observacaoController = TextEditingController();
  final TextEditingController solucaoController = TextEditingController();

  // Adicione aqui as variáveis para os dropdowns, se necessário
  // String? selectedCategoriaId;

  CategoriaProblema? selectedCategoria;
  SubcategoriaProblema? selectedSubcategoria;
  List<SubcategoriaProblema> subcategoriasDisponiveis = [];

  void dispose() {
    observacaoController.dispose();
    solucaoController.dispose();
  }
}

class ReportFormScreen extends StatefulWidget {
  final int ordemServicoId;
  final RelatorioCampo? relatorioParaEditar;
  const ReportFormScreen({
    super.key,
    required this.ordemServicoId,
    this.relatorioParaEditar,
  });

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiClient = ApiClient(API_BASE_URL);
  final _dbHelper = DatabaseHelper();
  final _osRepository = OsRepository();

  // Controladores para os campos de texto
  final _dataController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _materialController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _localServicoController = TextEditingController();

  // Variáveis de estado
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  TipoRelatorio? _selectedTipoRelatorio;
  List<HorasRelatorioTecnico> _horasCalculadas = [];
  List<TipoRelatorio> _tiposDeRelatorioDisponiveis = [];
  List<CategoriaProblema> _categoriasDeProblema = [];

  // Controladores para os campos de KM Rodado
  final Map<String, TextEditingController> _kmControllers = {};

  final List<ProblemaRelatorioFormModel> _problemas = [
    ProblemaRelatorioFormModel(),
  ];

  final SignatureController _assinaturaExecutanteController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _assinaturaClienteController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    // 2. No initState, verifica se estamos a editar e pré-preenche o formulário
    if (widget.relatorioParaEditar != null) {
      _preencherFormularioParaEdicao();
    } else {
      // Se estamos a criar, o comportamento é o mesmo de antes
      _dataController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      _fetchInitialData();
    }
  }

  void _preencherFormularioParaEdicao() {
    final relatorio = widget.relatorioParaEditar!;

    // Pré-preenche os controladores e variáveis de estado com dados simples
    _selectedDate = relatorio.dataRelatorio;
    _dataController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _descricaoController.text = relatorio.descricaoAtividades;
    _materialController.text = relatorio.materialUtilizado ?? '';
    _observacoesController.text = relatorio.observacoesAdicionais ?? '';
    _localServicoController.text = relatorio.localServico ?? '';

    // Busca os dados da API (como tipos de relatório e categorias de problema)
    _fetchInitialData().then((_) {
      // Após os dados serem carregados, executa o resto do preenchimento
      if (!mounted) return;

      // Pré-preenche o Tipo de Relatório
      setState(() {
        _selectedTipoRelatorio = _tiposDeRelatorioDisponiveis
            .firstWhereOrNull((tipo) => tipo.id == relatorio.tipoRelatorio.id);
      });

      // Pré-preenche os controladores de KM Rodado
      for (var horaSalva in relatorio.horas) {
        if (_kmControllers.containsKey(horaSalva.tecnico)) {
          _kmControllers[horaSalva.tecnico]!.text =
              horaSalva.kmRodado.toStringAsFixed(2).replaceAll('.', ',');
        }
      }

      // Pré-preenche a lista de problemas, incluindo Categoria e Subcategoria
      setState(() {
        _problemas.clear();
        for (var problema in relatorio.problemas) {
          final formModel = ProblemaRelatorioFormModel();

          // Encontra e seleciona a Categoria (de forma case-insensitive e sem espaços)
          final categoriaSelecionada = _categoriasDeProblema.firstWhereOrNull(
              (cat) =>
                  cat.nome.trim().toLowerCase() ==
                  problema.categoria.trim().toLowerCase());

          if (categoriaSelecionada != null) {
            formModel.selectedCategoria = categoriaSelecionada;
            formModel.subcategoriasDisponiveis =
                categoriaSelecionada.subcategorias;

            // --- A CORREÇÃO PRINCIPAL ESTÁ AQUI ---
            // Encontra e seleciona a Subcategoria (de forma case-insensitive e sem espaços)
            if (problema.subcategoria != null &&
                problema.subcategoria!.isNotEmpty) {
              final subcategoriaSelecionada = categoriaSelecionada.subcategorias
                  .firstWhereOrNull((sub) =>
                      sub.nome.trim().toLowerCase() ==
                      problema.subcategoria!.trim().toLowerCase());
              formModel.selectedSubcategoria = subcategoriaSelecionada;
            }
          }

          // Preenche os campos de texto do problema
          formModel.observacaoController.text = problema.observacao ?? '';
          formModel.solucaoController.text = problema.solucaoAplicada ?? '';
          _problemas.add(formModel);
        }

        if (_problemas.isEmpty) {
          _problemas.add(ProblemaRelatorioFormModel());
        }
      });
    });
  }

  @override
  void dispose() {
    _dataController.dispose();
    _descricaoController.dispose();
    _materialController.dispose();
    _observacoesController.dispose();
    _localServicoController.dispose();
    for (var controller in _kmControllers.values) {
      controller.dispose();
    }
    _assinaturaClienteController.dispose();
    for (var problema in _problemas) {
      problema.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dadosCalculados = await _osRepository.getDadosCalculadosRelatorio(
        widget.ordemServicoId,
        _selectedDate,
      );
      final tiposDeRelatorio =
          await _osRepository.getTiposRelatorio(); // Nova chamada
      final categoriasDeProblema = await _osRepository.getCategoriasProblema();

      if (mounted) {
        setState(() {
          // Atribui os resultados às variáveis de estado corretas
          _tiposDeRelatorioDisponiveis = tiposDeRelatorio;
          _horasCalculadas = dadosCalculados.horasCalculadas;
          _categoriasDeProblema = categoriasDeProblema;

          _criaKmControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erro ao carregar dados: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  void _criaKmControllers() {
    for (var controller in _kmControllers.values) {
      controller.dispose();
    }
    _kmControllers.clear();
    for (var hora in _horasCalculadas) {
      _kmControllers[hora.tecnico] = TextEditingController(
        text: hora.kmRodado.toStringAsFixed(2).replaceAll('.', ','),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      // --- CORREÇÃO APLICADA AQUI ---
      // 1. Atualiza o estado ANTES de buscar os novos dados.
      setState(() {
        _selectedDate = picked;
        _dataController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

        // 2. O passo mais importante: Limpa a seleção do dropdown.
        _selectedTipoRelatorio = null;
      });

      // 3. Agora, com a seleção já limpa, busca os dados para a nova data.
      await _fetchInitialData();
    }
  }

  Future<void> _saveReport() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha todos os campos obrigatórios.')),
      );
      return;
    }

    if (_selectedTipoRelatorio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione o Tipo de Relatório.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // A sua lógica para criar o payload permanece a mesma
    final List<Map<String, dynamic>> problemasPayload = _problemas.map((p) {
      return {
        'categoria': p.selectedCategoria?.id,
        'subcategoria': p.selectedSubcategoria?.id,
        'observacao': p.observacaoController.text,
        'solucao_aplicada': p.solucaoController.text,
      };
    }).toList();

    String? assinaturaExecutanteBase64;
    if (!_assinaturaExecutanteController.isEmpty) {
      final data = await _assinaturaExecutanteController.toPngBytes();
      if (data != null) {
        assinaturaExecutanteBase64 =
            'data:image/png;base64,${base64Encode(data)}';
      }
    }

    String? assinaturaClienteBase64;
    if (!_assinaturaClienteController.isEmpty) {
      final data = await _assinaturaClienteController.toPngBytes();
      if (data != null) {
        assinaturaClienteBase64 = 'data:image/png;base64,${base64Encode(data)}';
      }
    }

    final List<Map<String, dynamic>> horasPayload = [];
    for (var hora in _horasCalculadas) {
      horasPayload.add({
        'tecnico': hora.tecnico,
        'horas_normais': hora.horasNormaisDecimal,
        'horas_extras_60': hora.horasExtras60Decimal,
        'horas_extras_100': hora.horasExtras100Decimal,
        'km_rodado':
            _kmControllers[hora.tecnico]?.text.replaceAll(',', '.') ?? '0.00',
      });
    }

    final payload = {
      'data_relatorio': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'tipo_relatorio': _selectedTipoRelatorio!.id,
      'descricao_atividades': _descricaoController.text,
      'material_utilizado': _materialController.text,
      'observacoes_adicionais': _observacoesController.text,
      'local_servico': _localServicoController.text,
      'horas': horasPayload,
      'problemas': problemasPayload,
      'assinatura_executante_data': assinaturaExecutanteBase64,
      'assinatura_cliente_data': assinaturaClienteBase64,
    };

    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    try {
      final bool isEditing = widget.relatorioParaEditar != null;
      String successMessage;

      if (isOnline) {
        if (isEditing) {
          await _apiClient.put(
            '/relatorios-campo/${widget.relatorioParaEditar!.id}/',
            payload,
          );
          successMessage = 'Relatório atualizado com sucesso!';
        } else {
          await _apiClient.post(
            '/ordens-servico/${widget.ordemServicoId}/relatorios/novo/',
            payload,
          );
          successMessage = 'Relatório criado com sucesso!';
        }
      } else {
        // OFFLINE
        if (isEditing) {
          await _dbHelper.addPendingAction(
            widget.ordemServicoId,
            'edit_report',
            {'relatorio_id': widget.relatorioParaEditar!.id, ...payload},
          );
          successMessage = 'Alterações no relatório salvas offline.';
        } else {
          await _dbHelper.addPendingAction(
              widget.ordemServicoId, 'create_report', payload);
          successMessage =
              'Relatório salvo offline. Será sincronizado em breve.';
        }
        final relatorioTemporario = RelatorioCampo.fromPayload(
            payload, _tiposDeRelatorioDisponiveis, _categoriasDeProblema);
        await _dbHelper.addRelatorioToCache(
            widget.ordemServicoId, relatorioTemporario);
      }

      if (!mounted) return;

      // --- BLOCO DE SUCESSO UNIFICADO ---
      // Exibe a mensagem de sucesso e retorna para a tela anterior
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: isOnline
              ? AppColors.success
              : AppColors.warning, // Supondo que AppColors.success existe
        ),
      );
      Navigator.of(context)
          .pop(true); // O 'true' avisa a tela anterior para recarregar os dados
    } catch (e) {
      // O bloco de erro já estava correto: exibe a mensagem e permanece na tela
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Relatório')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage!, textAlign: TextAlign.center),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dataController,
                                decoration: const InputDecoration(
                                  labelText: 'Data do Relatório *',
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                readOnly: true,
                                onTap: () => _selectDate(context),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<TipoRelatorio>(
                                value: _selectedTipoRelatorio,
                                // 'isExpanded: true' é a chave para permitir que o texto se expanda e use o espaço
                                isExpanded: true,
                                items: _tiposDeRelatorioDisponiveis.map((tipo) {
                                  // --- INÍCIO DA CORREÇÃO ---
                                  // Removemos o widget 'Flexible' e usamos apenas o 'Text'.
                                  // O 'Text' com 'overflow' já sabe como lidar com texto comprido.
                                  return DropdownMenuItem<TipoRelatorio>(
                                    value: tipo,
                                    child: Text(
                                      tipo.nome,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                  // --- FIM DA CORREÇÃO ---
                                }).toList(),
                                onChanged: (value) {
                                  setState(
                                      () => _selectedTipoRelatorio = value);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Tipo de Relatório *',
                                ),
                                validator: (value) =>
                                    value == null ? 'Obrigatório' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descricaoController,
                          decoration: const InputDecoration(
                            labelText: 'Descrição das Atividades *',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _materialController,
                          decoration: const InputDecoration(
                            labelText: 'Materiais/Peças Utilizadas',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _localServicoController,
                          decoration: const InputDecoration(
                            labelText: 'Local do Serviço',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _observacoesController,
                          decoration: const InputDecoration(
                            labelText: 'Observações Adicionais',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Dados de Horas e Deslocamento',
                          style: AppTextStyles.subtitle1,
                        ),
                        const SizedBox(height: 8),
                        _buildHorasTable(),
                        const SizedBox(height: 24),
                        _buildProblemasSection(),
                        const SizedBox(height: 24),
                        _buildAssinaturasSection(),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveReport,
                          child: const Text('Salvar Relatório'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHorasTable() {
    if (_horasCalculadas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text('Nenhum ponto válido registrado para esta data.'),
      );
    }
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Técnico', style: AppTextStyles.caption),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Normais',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Extras 50%',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Extras 100%',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'KM Rodado',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        ..._horasCalculadas.map((hora) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(hora.tecnico, style: AppTextStyles.body2),
              ),

              // CORREÇÃO: Usar as propriedades com final "HHMM" para exibir na tela
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  hora.horasNormaisHHMM,
                  style: AppTextStyles.body2,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  hora.horasExtras60HHMM,
                  style: AppTextStyles.body2,
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  hora.horasExtras100HHMM,
                  style: AppTextStyles.body2,
                  textAlign: TextAlign.center,
                ),
              ),

              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TextFormField(
                    controller: _kmControllers[hora.tecnico],
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildProblemasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Problemas Identificados', style: AppTextStyles.subtitle1),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _problemas.length,
          itemBuilder: (context, index) {
            return _buildProblemaCard(index);
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.center,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _problemas.add(ProblemaRelatorioFormModel());
              });
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Adicionar Problema'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProblemaCard(int index) {
    final problema = _problemas[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do Card com o número e o botão de remover
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Problema #${index + 1}', style: AppTextStyles.subtitle1),
                if (_problemas.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () {
                      setState(() {
                        problema.dispose();
                        _problemas.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            //--- INÍCIO DAS ALTERAÇÕES ---

            // Dropdown de Categoria do Problema
            DropdownButtonFormField<CategoriaProblema>(
              value: problema.selectedCategoria,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Categoria do Problema *',
              ),
              items: _categoriasDeProblema.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.nome, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  // Atualiza a categoria selecionada para este problema
                  problema.selectedCategoria = newValue;
                  // Limpa a subcategoria anterior
                  problema.selectedSubcategoria = null;
                  // Atualiza a lista de subcategorias disponíveis com base na nova categoria
                  problema.subcategoriasDisponiveis =
                      newValue?.subcategorias ?? [];
                });
              },
              validator: (value) => value == null ? 'Campo obrigatório' : null,
            ),
            const SizedBox(height: 16),

            // Dropdown de Subcategoria do Problema
            DropdownButtonFormField<SubcategoriaProblema>(
              value: problema.selectedSubcategoria,
              isExpanded: true,
              // A dica (hint) só aparece se houver uma categoria selecionada mas nenhuma subcategoria
              hint: Text(
                problema.selectedCategoria == null
                    ? 'Selecione uma categoria primeiro'
                    : 'Nenhuma subcategoria',
              ),
              decoration: const InputDecoration(
                labelText: 'Subcategoria do Problema',
              ),
              // Os itens deste dropdown são preenchidos dinamicamente
              items: problema.subcategoriasDisponiveis.map((sub) {
                return DropdownMenuItem(
                  value: sub,
                  child: Text(sub.nome, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  problema.selectedSubcategoria = newValue;
                });
              },
              // O dropdown fica desabilitado se não houver subcategorias disponíveis
              disabledHint: Text(
                problema.selectedCategoria == null
                    ? 'Selecione uma categoria primeiro'
                    : 'Nenhuma subcategoria',
              ),
            ),
            const SizedBox(height: 16),

            //--- FIM DAS ALTERAÇÕES ---

            // Campos de texto que você já tinha
            TextFormField(
              controller: problema.observacaoController,
              decoration: const InputDecoration(
                labelText: 'Comentário / Observação do Problema',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: problema.solucaoController,
              decoration: const InputDecoration(
                labelText: 'Solução Aplicada para este Problema',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssinaturasSection() {
    return Column(
      children: [
        _buildSignaturePad(
          title: 'Assinatura do Executante',
          controller: _assinaturaExecutanteController,
        ),
        const SizedBox(height: 24),
        _buildSignaturePad(
          title: 'Assinatura do Cliente',
          controller: _assinaturaClienteController,
        ),
      ],
    );
  }

  Widget _buildSignaturePad({
    required String title,
    required SignatureController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.subtitle1),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Signature(
              controller: controller,
              height: 150,
              backgroundColor: AppColors.surface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => controller.clear(),
            child: const Text('Limpar'),
          ),
        ),
      ],
    );
  }
}
