// lib/models/despesa.dart

import 'dart:convert';
import 'package:flutter_application/models/categoria_despesa.dart';
import 'package:flutter_application/models/forma_pagamento.dart';
import 'categoria_despesa.dart';
import 'forma_pagamento.dart';

class Despesa {
  final int id;
  final String descricao;
  final double valor;
  final DateTime dataDespesa;
  final String tecnico;
  final String? local;
  final bool isAdiantamento;
  final String? comprovanteUrl;
  final CategoriaDespesa? categoria;
  final FormaPagamento? formaPagamento;
  final String? statusAprovacao;
  final String? aprovadoPor;
  final DateTime? dataAprovacao;
  final String? comentarioAprovacao;
  final bool isPending;
  final int ordemServicoId;
  final String? statusPagamento;
  final String? responsavelPagamento;
  final DateTime? dataPagamento;
  final String? comentarioPagamento;
  final String? osNumero;
  final String? osTitulo;

  Despesa({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.dataDespesa,
    required this.tecnico,
    this.local,
    this.isAdiantamento = false,
    this.comprovanteUrl,
    this.isPending = false,
    required this.ordemServicoId,
    this.statusPagamento,
    this.responsavelPagamento,
    this.dataPagamento,
    this.comentarioPagamento,
    this.categoria,
    this.formaPagamento,
    this.statusAprovacao,
    this.aprovadoPor,
    this.dataAprovacao,
    this.comentarioAprovacao,
    this.osNumero,
    this.osTitulo,
  });

  factory Despesa.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr == "null") return null;
      return DateTime.tryParse(dateStr);
    }

    return Despesa(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      descricao:
          json['descricao']?.toString() ?? 'N/A', // Adicionado .toString()
      valor: double.tryParse(json['valor'].toString()) ?? 0.0,
      dataDespesa: DateTime.parse(json['data_despesa'].toString()),
      // Convertendo explicitamente para String
      tecnico: json['tecnico']?.toString() ??
          json['criado_por']?['usuario']?.toString() ??
          'N/A',
      local: json['local_despesa']?.toString() ?? 'N/A',
      isAdiantamento: json['is_adiantamento'] ?? false,
      comprovanteUrl:
          json['comprovante_anexo']?.toString(), // Adicionado .toString()

      // Certifique-se que o tratamento de nulls e conversão para String está correto
      categoria: json['categoria_despesa'] != null
          ? CategoriaDespesa.fromJson(json['categoria_despesa'])
          : null,
      formaPagamento: json['tipo_pagamento'] != null
          ? FormaPagamento.fromJson(json['tipo_pagamento'])
          : null,
      isPending: false,

      // Lendo os novos campos do JSON e convertendo para String
      statusAprovacao: json['status_aprovacao']?.toString(),
      aprovadoPor: json['aprovado_por']?.toString() ??
          json['aprovado_por_id']?.toString(), // Lida com o ID
      dataAprovacao: parseDate(json['data_aprovacao']?.toString()),
      comentarioAprovacao: json['comentario_aprovacao']?.toString(),
      ordemServicoId: json['ordem_servico'] ?? 0,

// --- CORREÇÃO APLICADA AQUI ---
      statusPagamento: json['status_pagamento']?.toString(),
      responsavelPagamento: json['responsavel_pagamento']?.toString(),
      dataPagamento: parseDate(json['data_pagamento']?.toString()),
      comentarioPagamento: json['comentario_pagamento']?.toString(),
      osNumero: json['numero_os']?.toString(),
      osTitulo: json['titulo_os']?.toString(),
    );
  }

  // O método toJson não precisa ser alterado por enquanto,
  // pois o app apenas lê essas informações, não as envia.
  Map<String, dynamic> toJson() => {
        'id': id,
        'descricao': descricao,
        'valor': valor,
        'data_despesa': dataDespesa.toIso8601String(),
        'tecnico': tecnico,
        'local_despesa':
            local, // Corrigido para corresponder ao fromJson ('local_despesa')
        'is_adiantamento': isAdiantamento,
        'comprovante_anexo':
            comprovanteUrl, // Corrigido para 'comprovante_anexo'

        // --- CORREÇÃO PRINCIPAL APLICADA AQUI ---
        'categoria_despesa': categoria?.toJson(),
        'tipo_pagamento':
            formaPagamento?.toJson(), // Alterado de 'forma_pagamento'
        // --- FIM DA CORREÇÃO ---

        'isPending': isPending,
        // Adicionando os outros campos para garantir a simetria
        'status_aprovacao': statusAprovacao,
        'aprovado_por': aprovadoPor,
        'data_aprovacao': dataAprovacao?.toIso8601String(),
        'comentario_aprovacao': comentarioAprovacao,
        'status_pagamento': statusPagamento,
        'responsavel_pagamento': responsavelPagamento,
        'data_pagamento': dataPagamento?.toIso8601String(),
        'comentario_pagamento': comentarioPagamento,
      };
}
