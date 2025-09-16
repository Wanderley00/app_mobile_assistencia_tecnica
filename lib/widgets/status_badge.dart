// lib/widgets/status_badge.dart

import 'package:flutter/material.dart';
import '../main.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    // O switch agora entende tanto os status de OS quanto os de Despesa
    switch (status.toUpperCase()) {
      // Status de OS
      case 'EM_EXECUCAO':
        color = AppColors.warning;
        text = 'Em Execução';
        break;
      case 'CONCLUIDA':
        color = AppColors.success;
        text = 'Concluída';
        break;
      case 'PLANEJADA':
        color = AppColors.primaryLight;
        text = 'Planejada';
        break;

      // --- ADIÇÃO: Status de Aprovação de Despesa ---
      case 'APROVADO':
      case 'APROVADA': // Adicionado para cobrir ambas as possibilidades
        color = AppColors.success;
        text = 'Aprovado';
        break;
      case 'REPROVADO':
      case 'REJEITADA':
        color = AppColors.error;
        text = 'Reprovado';
        break;

      // --- ADIÇÃO: Status de Pagamento de Despesa ---
      case 'PAGO':
        color = AppColors.success;
        text = 'Pago';
        break;
      case 'EM_ANALISE':
        color = AppColors.primaryLight;
        text = 'Em Análise';
        break;
      case 'CANCELADO':
        color = AppColors.error;
        text = 'Cancelado';
        break;

      // Status Padrão/Pendentes
      case 'AGUARDANDO':
      case 'PENDENTE':
      default:
        color = AppColors.textSecondary;
        text = 'Aguardando';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}
