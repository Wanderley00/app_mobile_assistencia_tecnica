// lib/models/tipo_relatorio.dart

import 'package:flutter/foundation.dart';

@protected
class TipoRelatorio {
  final int id;
  final String nome;

  TipoRelatorio({required this.id, required this.nome});

  factory TipoRelatorio.fromJson(Map<String, dynamic> json) {
    return TipoRelatorio(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] as String? ?? 'N/A',
    );
  }

  // --- ADICIONE ESTE MÉTODO ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
    };
  }
  // --- FIM DO MÉTODO ADICIONADO ---
}
