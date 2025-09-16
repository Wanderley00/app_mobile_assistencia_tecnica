// lib/models/membro_equipe.dart

class MembroEquipe {
  final String usuario;
  final String? funcao;

  MembroEquipe({required this.usuario, this.funcao});

  factory MembroEquipe.fromJson(Map<String, dynamic> json) {
    return MembroEquipe(
      usuario: json['usuario'] ?? 'N/A',
      funcao: json['funcao'],
    );
  }

  Map<String, dynamic> toJson() => {'usuario': usuario, 'funcao': funcao};
}
