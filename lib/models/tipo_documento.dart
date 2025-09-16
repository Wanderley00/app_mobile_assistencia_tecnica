// lib/models/tipo_documento.dart

class TipoDocumento {
  final int id;
  final String nome;

  TipoDocumento({required this.id, required this.nome});

  factory TipoDocumento.fromJson(Map<String, dynamic> json) {
    return TipoDocumento(id: json['id'], nome: json['nome']);
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
