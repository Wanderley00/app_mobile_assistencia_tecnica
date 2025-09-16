// lib/models/equipamento.dart

class Equipamento {
  final String nome;
  final String modelo;
  Equipamento({required this.nome, required this.modelo});

  factory Equipamento.fromJson(Map<String, dynamic> json) =>
      Equipamento(nome: json['nome'] ?? 'N/A', modelo: json['modelo'] ?? 'N/A');

  Map<String, dynamic> toJson() => {'nome': nome, 'modelo': modelo};
}
