// lib/screens/photo_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart'; // Para os estilos e a API_BASE_URL

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database_helper.dart';
import '../os_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PhotoFormScreen extends StatefulWidget {
  final int relatorioId;

  const PhotoFormScreen({super.key, required this.relatorioId});

  @override
  State<PhotoFormScreen> createState() => _PhotoFormScreenState();
}

class _PhotoFormScreenState extends State<PhotoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  // --- INÍCIO DAS CORREÇÕES E ADIÇÕES ---

  // 2. DECLARE AS INSTÂNCIAS AQUI
  final _dbHelper = DatabaseHelper();
  final _osRepository = OsRepository();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Falha ao selecionar imagem: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria de Fotos'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Câmara'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _savePhoto() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, selecione uma imagem.'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final isOnline =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

    try {
      if (isOnline) {
        // LÓGICA ONLINE: Envia diretamente para a API
        // (Vamos precisar de um novo método no OsRepository para isto)
        await _osRepository.addPhotoToReportOnline(
          relatorioId: widget.relatorioId,
          description: _descriptionController.text,
          imageFile: _imageFile!,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto salva com sucesso!'),
              backgroundColor: AppColors.success),
        );
      } else {
        // LÓGICA OFFLINE: Salva localmente e adiciona à fila de sincronização
        // 1. Guarda a imagem num local permanente na aplicação
        final directory = await getApplicationDocumentsDirectory();
        final fileName = p.basename(_imageFile!.path);
        final permanentPath = '${directory.path}/$fileName';
        await _imageFile!.copy(permanentPath);

        // 2. Cria o payload para a ação pendente
        final payload = {
          'relatorio_id': widget.relatorioId,
          'descricao': _descriptionController.text,
          'local_image_path': permanentPath,
        };

        // 3. Adiciona à fila de sincronização
        await _dbHelper.addPendingAction(
            0, 'add_photo', payload); // OS ID não é relevante aqui

        // 4. (Opcional, mas recomendado) Adiciona ao cache para feedback imediato
        // Esta parte é mais complexa, podemos adicionar depois se necessário.

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Foto salva offline. Será sincronizada em breve.'),
              backgroundColor: AppColors.warning),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar foto: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Foto ao Relatório'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Área de pré-visualização da imagem
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade100,
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Center(
                          child: Icon(Icons.image_outlined,
                              size: 80, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Botão para selecionar imagem
              OutlinedButton.icon(
                onPressed: () => _showImageSourceActionSheet(context),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Selecionar Imagem'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              // Campo de descrição
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição da Foto',
                  hintText: 'Ex: Painel antes da intervenção.',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'A descrição é obrigatória.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Botão de salvar
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _savePhoto,
                icon: _isLoading
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.save),
                label: const Text('Salvar Foto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
