// lib/screens/conclusion_signature_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../main.dart';
import '../api_client.dart';

class ConclusionSignatureScreen extends StatefulWidget {
  final int osId;
  const ConclusionSignatureScreen({super.key, required this.osId});

  @override
  State<ConclusionSignatureScreen> createState() =>
      _ConclusionSignatureScreenState();
}

class _ConclusionSignatureScreenState extends State<ConclusionSignatureScreen> {
  final _apiClient = ApiClient(API_BASE_URL);
  bool _isLoading = false;

  final SignatureController _assinaturaExecutanteController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final SignatureController _assinaturaClienteController =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  @override
  void dispose() {
    _assinaturaExecutanteController.dispose();
    _assinaturaClienteController.dispose();
    super.dispose();
  }

  Future<void> _concluirOS() async {
    if (_assinaturaExecutanteController.isEmpty ||
        _assinaturaClienteController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ambas as assinaturas são obrigatórias para concluir a OS.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Converte as assinaturas para Base64
      final execData = await _assinaturaExecutanteController.toPngBytes();
      final clienteData = await _assinaturaClienteController.toPngBytes();

      final String assinaturaExecutanteBase64 =
          'data:image/png;base64,${base64Encode(execData!)}';
      final String assinaturaClienteBase64 =
          'data:image/png;base64,${base64Encode(clienteData!)}';

      final payload = {
        'assinatura_executante_data': assinaturaExecutanteBase64,
        'assinatura_cliente_data': assinaturaClienteBase64,
      };

      // Envia para a nova API
      await _apiClient.post(
        '/ordens-servico/${widget.osId}/concluir/',
        payload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordem de Serviço concluída com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Fecha a tela de assinatura e a tela de detalhes, retornando 'true' para a lista
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao concluir OS: ${e.toString()}'),
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
      appBar: AppBar(title: const Text('Assinaturas de Conclusão')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _concluirOS,
              icon: const Icon(Icons.check_circle_outline),
              label: _isLoading
                  ? const Text('Concluindo...')
                  : const Text('Concluir Ordem de Serviço'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            )
          ],
        ),
      ),
    );
  }

  // Widget auxiliar copiado do report_form_screen.dart
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
