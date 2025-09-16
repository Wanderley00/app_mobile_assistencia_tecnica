// lib/models/forma_pagamento.dart

class FormaPagamento {
  final int id;
  final String nome;

  FormaPagamento({required this.id, required this.nome});

  factory FormaPagamento.fromJson(Map<String, dynamic> json) {
    return FormaPagamento(id: json['id'], nome: json['nome']);
  }

  // --- ADICIONE ESTE MÉTODO ---
  Map<String, dynamic> toJson() {
    return {'id': id, 'nome': nome};
  }
  // --- FIM DO MÉTODO ADICIONADO ---
}
