// lib/models/problema_relatorio.dart

class ProblemaRelatorio {
  final String categoria;
  final String? subcategoria;
  final String? observacao;
  final String? solucaoAplicada;

  ProblemaRelatorio({
    required this.categoria,
    this.subcategoria,
    this.observacao,
    this.solucaoAplicada,
  });

  factory ProblemaRelatorio.fromJson(Map<String, dynamic> json) {
    return ProblemaRelatorio(
      categoria: json['categoria'] ?? 'N/A',
      subcategoria: json['subcategoria'],
      observacao: json['observacao'],
      solucaoAplicada: json['solucao_aplicada'],
    );
  }

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        'subcategoria': subcategoria,
        'observacao': observacao,
        'solucao_aplicada': solucaoAplicada,
      };
}
