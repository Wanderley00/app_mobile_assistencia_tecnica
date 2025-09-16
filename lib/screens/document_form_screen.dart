// lib/screens/document_form_screen.dart (VERSÃO FINAL CORRIGIDA)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../database_helper.dart';
import '../models/tipo_documento.dart';
import '../os_repository.dart';
import '../models/documento_os.dart';
import '../api_client.dart';
import '../widgets/info_row.dart';

class DocumentFormScreen extends StatefulWidget {
  final int ordemServicoId;
  final DocumentoOS? documentoParaEditar;

  const DocumentFormScreen({
    super.key,
    required this.ordemServicoId,
    this.documentoParaEditar,
  });

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final ApiClient _apiClient = ApiClient(API_BASE_URL);

  bool _isLoading = false;
  late bool _isEditingMode;
  List<TipoDocumento> _tiposDocumento = [];
  TipoDocumento? _selectedTipo;
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _isEditingMode = widget.documentoParaEditar != null;

    if (_isEditingMode) {
      final doc = widget.documentoParaEditar!;
      _tituloController.text = doc.titulo;
      // Se você usa a descrição, descomente a linha abaixo
      // _descricaoController.text = (doc as dynamic).descricao ?? '';
    }
    _fetchTiposDocumento();
  }

  Future<void> _fetchTiposDocumento() async {
    final repository = OsRepository();
    setState(() => _isLoading = true);
    try {
      final tiposDocumento = await repository.getTiposDocumento();
      if (mounted) {
        setState(() {
          _tiposDocumento = tiposDocumento;
          if (_isEditingMode) {
            try {
              _selectedTipo = _tiposDocumento.firstWhere(
                (tipo) =>
                    tipo.nome == widget.documentoParaEditar!.tipoDocumento,
              );
            } catch (e) {
              _selectedTipo = null;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao buscar tipos: ${e.toString()}'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _saveDocument() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, selecione um tipo de documento.')));
      return;
    }
    if (!_isEditingMode && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecione um arquivo.')));
      return;
    }

    setState(() => _isLoading = true);
    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    final payload = {
      'titulo': _tituloController.text,
      'descricao': _descricaoController.text,
      'tipo_documento': _selectedTipo!.id.toString(),
    };

    try {
      if (_isEditingMode) {
        // --- LÓGICA DE EDIÇÃO ---
        final docId = widget.documentoParaEditar!.id;
        if (isOnline) {
          await _apiClient.put('/documentos/$docId/', payload);
        } else {
          // A linha com erro foi corrigida aqui, garantindo o escopo da variável.
          final offlinePayload = Map<String, dynamic>.from(payload);
          offlinePayload['documento_id'] = docId;
          await DatabaseHelper().addPendingAction(
              widget.ordemServicoId, 'edit_document', offlinePayload);
        }
      } else {
        // --- LÓGICA DE CRIAÇÃO ---
        if (isOnline) {
          await _apiClient.postMultipart(
            '/ordens-servico/${widget.ordemServicoId}/documentos/',
            payload,
            filePath: _pickedFile!.path!,
            fileField: 'arquivo',
          );
        } else {
          final offlinePayload = Map<String, dynamic>.from(payload);
          final appDocsDir = await getApplicationDocumentsDirectory();
          final fileName = path.basename(_pickedFile!.path!);
          final newFilePath = path.join(appDocsDir.path, fileName);
          final newFile = await File(_pickedFile!.path!).copy(newFilePath);
          offlinePayload['arquivo_caminho'] = newFile.path;
          await DatabaseHelper().addPendingAction(
              widget.ordemServicoId, 'add_document', offlinePayload);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditingMode
            ? 'Documento atualizado com sucesso!'
            : 'Documento salvo para sincronização!'),
        backgroundColor: AppColors.success,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Falha no envio: ${e.toString()}'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditingMode ? 'Editar Documento' : 'Anexar Novo Documento'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<TipoDocumento>(
                      value: _selectedTipo,
                      items: _tiposDocumento.map((tipo) {
                        return DropdownMenuItem<TipoDocumento>(
                            value: tipo, child: Text(tipo.nome));
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedTipo = value),
                      decoration: const InputDecoration(
                          labelText: 'Tipo de Documento *'),
                      validator: (value) =>
                          value == null ? 'Selecione um tipo' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                          labelText: 'Título do Documento *'),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Este campo é obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(
                          labelText: 'Descrição', alignLabelWithHint: true),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    if (!_isEditingMode)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(_pickedFile == null
                            ? 'Escolher arquivo *'
                            : 'Arquivo: ${_pickedFile!.name}'),
                        onPressed: _pickFile,
                      )
                    else
                      InfoRow(
                        icon: Icons.attach_file,
                        text: 'O anexo não pode ser alterado na edição.',
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _saveDocument,
                              child: Text(_isEditingMode
                                  ? 'Salvar Alterações'
                                  : 'Anexar Documento'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
