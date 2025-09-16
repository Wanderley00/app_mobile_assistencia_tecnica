// lib/widgets/os_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ordem_servico.dart';
import '../main.dart'; // Para AppColors e AppTextStyles
import 'info_row.dart';
import 'status_badge.dart';

class OsCard extends StatelessWidget {
  final OrdemServico ordemServico;
  final VoidCallback? onTap;

  const OsCard({super.key, required this.ordemServico, this.onTap});

  // --- ADIÇÃO 1: Função auxiliar para obter a cor do status ---
  /// Retorna uma cor baseada no status da Ordem de Serviço.
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'EM_EXECUCAO':
        return AppColors.warning;
      case 'CONCLUIDA':
        return AppColors.success;
      case 'PLANEJADA':
        return AppColors.primaryLight;
      default:
        return AppColors.textSecondary;
    }
  }

  // Função auxiliar de formatação de data (já existente)
  String _formatRelativeDate(DateTime date) {
    // 1. Converte a data (que vem em UTC do servidor) para a hora local do dispositivo.
    final localDate = date.toLocal();

    // 2. Realiza todas as comparações e formatações usando a data local.
    final now = DateTime.now();
    final difference = now.difference(localDate);

    if (difference.inHours < 24 && now.day == localDate.day) {
      return 'Hoje, às ${DateFormat.Hm().format(localDate)}';
    } else if (difference.inHours < 48 && now.day - localDate.day == 1) {
      return 'Ontem, às ${DateFormat.Hm().format(localDate)}';
    } else if (difference.inDays < 7) {
      // A lógica de "há X dias" não precisa de mudança, pois se baseia na diferença.
      return 'Há ${difference.inDays} dias';
    } else {
      return DateFormat('dd/MM/yyyy').format(localDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      // Adicionando clipBehavior para garantir que a barra de cor não "vaze"
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          // Garante que todos os filhos da Row tenham a mesma altura
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- ADIÇÃO 2: A barra de status colorida ---
              Container(
                width: 6.0, // Largura da barra
                color: _getStatusColor(ordemServico.status),
              ),

              // --- ADIÇÃO 3: Conteúdo original do card, agora dentro de um Expanded ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- LÓGICA ADICIONADA PARA O ÍCONE ---
                          Flexible(
                            child: Row(
                              children: [
                                // Se tiver ações pendentes, mostra o ícone
                                if (ordemServico.hasPendingActions)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Tooltip(
                                      message:
                                          'Dados pendentes de sincronização',
                                      child: Icon(
                                        Icons.sync_problem_rounded,
                                        color: AppColors.warning,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                // O número da OS agora precisa ser flexível
                                Flexible(
                                  child: Text(
                                    ordemServico.numeroOs,
                                    style: AppTextStyles.caption,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // --- FIM DA LÓGICA ADICIONADA ---

                          // O StatusBadge continua aqui
                          StatusBadge(status: ordemServico.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(ordemServico.tituloServico,
                          style: AppTextStyles.subtitle1),
                      const SizedBox(height: 12),
                      InfoRow(
                        icon: Icons.business,
                        text: ordemServico.cliente.razaoSocial,
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        icon: Icons.construction,
                        text:
                            '${ordemServico.equipamento.nome} (${ordemServico.equipamento.modelo})',
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        icon: Icons.person_outline,
                        text: ordemServico.tecnicoResponsavel,
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Abertura: ${_formatRelativeDate(ordemServico.dataAbertura)}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
