// lib/models/categoria_despesa.dart

class CategoriaDespesa {
  final int id;
  final String nome;

  CategoriaDespesa({required this.id, required this.nome});

  factory CategoriaDespesa.fromJson(Map<String, dynamic> json) {
    return CategoriaDespesa(
      id: json['id'] as int? ?? 0,
      nome: json['nome'] as String? ?? 'N/A',
    );
  }

  // --- ADICIONE ESTE MÉTODO ---
  Map<String, dynamic> toJson() => {'id': id, 'nome': nome};
  // --- FIM DO MÉTODO ADICIONADO ---
}
