// lib/screens/expense_form_screen.dart

import 'package:flutter_application/models/forma_pagamento.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../main.dart';
import '../database_helper.dart';
import '../models/categoria_despesa.dart';
import '../models/forma_pagamento.dart';
import '../os_repository.dart';
import '../models/despesa.dart';
import '../models/documento_os.dart';
import '../models/membro_equipe.dart';
import '../api_client.dart';
import 'package:image_picker/image_picker.dart';

class ExpenseFormScreen extends StatefulWidget {
  final int ordemServicoId;
  // --- MUDANÇA 1: Construtor agora aceita uma despesa opcional para edição ---
  final Despesa? despesaParaEditar;

  const ExpenseFormScreen({
    super.key,
    required this.ordemServicoId,
    this.despesaParaEditar,
  });

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataController = TextEditingController();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _localController = TextEditingController();
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  bool _isLoading = true;
  String? _errorMessage;
  late bool _isEditingMode; // Para controlar o estado do formulário

  List<CategoriaDespesa> _categorias = [];
  List<FormaPagamento> _formasPagamento = [];

  int? _selectedCategoriaId;
  int? _selectedFormaPagamentoId;
  bool _isAdiantamento = false;

  // --- INÍCIO DA ALTERAÇÃO 2: A variável agora pode ser XFile ou PlatformFile ---
  dynamic _pickedFile;
  String _pickedFileName = '';

  @override
  void initState() {
    super.initState();
    // --- MUDANÇA 2: Lógica para preencher o formulário no modo de edição ---
    _isEditingMode = widget.despesaParaEditar != null;

    if (_isEditingMode) {
      // Se estamos editando, preenchemos os campos com os dados existentes
      final despesa = widget.despesaParaEditar!;
      _dataController.text =
          DateFormat('dd/MM/yyyy').format(despesa.dataDespesa);
      _valorController.text =
          despesa.valor.toStringAsFixed(2).replaceAll('.', ',');
      _descricaoController.text = despesa.descricao;
      _localController.text = despesa.local ?? '';
      _selectedCategoriaId = despesa.categoria?.id;
      _selectedFormaPagamentoId = despesa.formaPagamento?.id;
      _isAdiantamento = despesa.isAdiantamento;
    } else {
      // Se estamos criando, apenas define a data atual
      _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    }

    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    final repository = OsRepository();
    try {
      final categorias = await repository.getCategoriasDespesa();
      final formasPagamento = await repository.getFormasPagamento();
      if (mounted) {
        setState(() {
          _categorias = categorias;
          _formasPagamento = formasPagamento;
          _isLoading = false;
        });
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tirar Foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Escolher Arquivo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFileFromSystem();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _pickedFile = image;
          _pickedFileName = path.basename(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao selecionar imagem: $e')),
      );
    }
  }

  Future<void> _pickFileFromSystem() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
        _pickedFileName = result.files.first.name;
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    final payload = {
      'data_despesa': DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(_dataController.text)),
      'valor': _valorController.text.replaceAll(',', '.'),
      'descricao': _descricaoController.text,
      'local_despesa': _localController.text,
      'categoria_despesa': _selectedCategoriaId,
      'tipo_pagamento': _selectedFormaPagamentoId,
      'is_adiantamento': _isAdiantamento,
    };

    if (_isEditingMode) {
      payload['status_aprovacao'] = 'PENDENTE';
      payload['data_aprovacao'] = null;
      payload['comentario_aprovacao'] = null;
    }

    try {
      String? filePath;
      if (_pickedFile != null) {
        filePath = _pickedFile is XFile
            ? (_pickedFile as XFile).path
            : (_pickedFile as PlatformFile).path;
      }

      if (isOnline) {
        final despesaId = widget.despesaParaEditar?.id;

        // --- INÍCIO DA CORREÇÃO ONLINE ---
        if (_isEditingMode) {
          if (filePath != null) {
            // Editando E com um novo arquivo: usa PATCH multipart
            await _apiClient.patchMultipart(
              '/despesas/$despesaId/',
              payload,
              filePath: filePath,
              fileField: 'comprovante_anexo',
            );
          } else {
            // Editando SEM um novo arquivo: usa PUT normal
            await _apiClient.put('/despesas/$despesaId/', payload);
          }
        } else {
          // --- FIM DA CORREÇÃO ONLINE ---
          // Lógica de criação (já corrigida anteriormente)
          if (filePath != null) {
            await _apiClient.postMultipart(
              '/ordens-servico/${widget.ordemServicoId}/despesas/',
              payload,
              filePath: filePath,
              fileField: 'comprovante_anexo',
            );
          } else {
            await _apiClient.post(
                '/ordens-servico/${widget.ordemServicoId}/despesas/', payload);
          }
        }

        if (mounted) {
          final successMessage = _isEditingMode
              ? 'Alterações salvas! A aprovação foi reiniciada.'
              : 'Despesa salva com sucesso!';

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ));
          Navigator.of(context).pop(true);
        }
      } else {
        // --- INÍCIO DA CORREÇÃO OFFLINE ---
        final offlinePayload = Map<String, dynamic>.from(payload);
        if (filePath != null) {
          offlinePayload['comprovante_caminho'] = filePath;
        }

        if (_isEditingMode) {
          final despesaId = widget.despesaParaEditar!.id;
          offlinePayload['despesa_id'] = despesaId;
          await DatabaseHelper().addPendingAction(
              widget.ordemServicoId, 'edit_expense', offlinePayload);
        } else {
          // --- FIM DA CORREÇÃO OFFLINE ---
          await DatabaseHelper().addPendingAction(
              widget.ordemServicoId, 'create_expense', offlinePayload);
        }

        if (mounted) {
          final offlineMessage = _isEditingMode
              ? 'Alterações salvas offline. A aprovação será reiniciada na sincronização.'
              : 'Despesa salva offline. Será sincronizada em breve.';

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(offlineMessage),
            backgroundColor: AppColors.warning,
          ));
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar despesa: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- MUDANÇA 4: UI adaptativa (título e botão) ---
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditingMode ? 'Editar Despesa' : 'Registrar Despesa'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Erro ao carregar dados: $_errorMessage'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _dataController,
                          decoration: const InputDecoration(
                            labelText: 'Data da Despesa *',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              String formattedDate = DateFormat(
                                'dd/M/yyyy',
                              ).format(pickedDate);
                              setState(() {
                                _dataController.text = formattedDate;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _valorController,
                          decoration: const InputDecoration(
                            labelText: 'Valor (R\$) *',
                            prefixText: 'R\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Este campo é obrigatório';
                            if (double.tryParse(value.replaceAll(',', '.')) ==
                                null) return 'Insira um valor numérico válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedCategoriaId,
                          items: _categorias.map((categoria) {
                            return DropdownMenuItem<int>(
                              value: categoria.id,
                              child: Text(categoria.nome),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCategoriaId = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Categoria da Despesa *',
                          ),
                          validator: (value) =>
                              value == null ? 'Selecione uma categoria' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descricaoController,
                          decoration: const InputDecoration(
                            labelText: 'Descrição *',
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Este campo é obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _localController,
                          decoration: const InputDecoration(
                            labelText: 'Local da Despesa (Estabelecimento)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedFormaPagamentoId,
                          items: _formasPagamento.map((forma) {
                            return DropdownMenuItem<int>(
                              value: forma.id,
                              child: Text(forma.nome),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedFormaPagamentoId = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Forma de Pagamento *',
                          ),
                          validator: (value) => value == null
                              ? 'Selecione uma forma de pagamento'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text("É Adiantamento?"),
                          subtitle: const Text(
                            "Marque se esta despesa for um adiantamento.",
                          ),
                          value: _isAdiantamento,
                          onChanged: (newValue) {
                            setState(() {
                              _isAdiantamento = newValue!;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            _pickedFileName.isEmpty
                                ? 'Anexar Comprovante'
                                : 'Arquivo: $_pickedFileName',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: _showAttachmentOptions,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveExpense,
                            child: _isLoading
                                ? const SizedBox(/* ... */)
                                : Text(_isEditingMode
                                    ? 'Salvar Alterações'
                                    : 'Salvar Despesa'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
