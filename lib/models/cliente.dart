// lib/models/cliente.dart

class Cliente {
  final String razaoSocial;
  Cliente({required this.razaoSocial});

  factory Cliente.fromJson(Map<String, dynamic> json) =>
      Cliente(razaoSocial: json['razao_social'] ?? 'N/A');

  Map<String, dynamic> toJson() => {'razao_social': razaoSocial};
}
