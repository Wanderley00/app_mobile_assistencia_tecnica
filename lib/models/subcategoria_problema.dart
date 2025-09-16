// lib/models/subcategoria_problema.dart

class SubcategoriaProblema {
  final int id;
  final String nome;

  SubcategoriaProblema({required this.id, required this.nome});

  factory SubcategoriaProblema.fromJson(Map<String, dynamic> json) {
    return SubcategoriaProblema(id: json['id'], nome: json['nome']);
  }
}
