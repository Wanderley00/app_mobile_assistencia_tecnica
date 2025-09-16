// lib/screens/expense_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/despesa.dart';
import '../main.dart'; // Para AppColors e AppTextStyles
import '../widgets/status_badge.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Despesa despesa;

  const ExpenseDetailScreen({super.key, required this.despesa});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Despesa'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailCard('Informações da Despesa', [
              _buildInfoRow('Descrição:', despesa.descricao),
              // O campo "Data" da despesa geralmente não tem hora, então não precisa de conversão.
              _buildInfoRow('Data:',
                  DateFormat('dd/MM/yyyy').format(despesa.dataDespesa)),
              _buildInfoRow(
                  'Valor:', 'R\$ ${despesa.valor.toStringAsFixed(2)}'),
              _buildInfoRow('Responsável:', despesa.tecnico),
              _buildInfoRow('Categoria:', despesa.categoria?.nome ?? 'N/A'),
              _buildInfoRow(
                  'Forma de Pagamento:', despesa.formaPagamento?.nome ?? 'N/A'),
              _buildInfoRow('Local (Estabelecimento):', despesa.local ?? 'N/A'),
              _buildInfoRow(
                  'É Adiantamento?:', despesa.isAdiantamento ? 'Sim' : 'Não'),
            ]),
            const SizedBox(height: 16),
            _buildDetailCard('Status de Aprovação', [
              _buildInfoRow('Status:', despesa.statusAprovacao ?? 'N/A',
                  isStatus: true),
              _buildInfoRow('Aprovado Por:', despesa.aprovadoPor ?? 'N/A'),
              _buildInfoRow(
                  'Data da Aprovação:',
                  despesa.dataAprovacao != null
                      // --- CORREÇÃO APLICADA AQUI ---
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(despesa.dataAprovacao!.toLocal())
                      : 'N/A'),
              _buildInfoRow(
                  'Comentário:', despesa.comentarioAprovacao ?? 'Nenhum.'),
            ]),
            const SizedBox(height: 16),
            _buildDetailCard('Informações de Pagamento (Contas a Pagar)', [
              _buildInfoRow(
                  'Status do Pagamento:', despesa.statusPagamento ?? 'N/A',
                  isStatus: true),
              _buildInfoRow('Responsável pelo Pagamento:',
                  despesa.responsavelPagamento ?? 'N/A'),
              _buildInfoRow(
                  'Data do Pagamento:',
                  despesa.dataPagamento != null
                      // --- CORREÇÃO APLICADA AQUI TAMBÉM ---
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(despesa.dataPagamento!.toLocal())
                      : 'N/A'),
              _buildInfoRow('Comentário do Pagamento:',
                  despesa.comentarioPagamento ?? 'Nenhum.'),
            ]),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para criar os cards de seção
  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
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

  // Widget auxiliar para criar as linhas de informação
  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            flex: 3,
            child: isStatus
                ? StatusBadge(status: value)
                : Text(value,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
