// lib/models/foto_relatorio.dart

class FotoRelatorio {
  final int id;
  final String? imagemUrl;
  final String descricao;
  final bool isPending;
  final String? localFilePath;

  FotoRelatorio({
    required this.id,
    this.imagemUrl,
    required this.descricao,
    this.isPending = false,
    this.localFilePath,
  });

  FotoRelatorio copyWith({
    String? localFilePath,
  }) {
    return FotoRelatorio(
      id: id,
      imagemUrl: imagemUrl,
      descricao: descricao,
      isPending: isPending,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  // --- INÍCIO DA CORREÇÃO ---
  factory FotoRelatorio.fromJson(Map<String, dynamic> json) {
    return FotoRelatorio(
      id: json['id'],
      imagemUrl: json['imagem_url'], // Já lê a URL completa
      descricao: json['descricao'] ?? '',
      // Lê o caminho local do cache, se existir
      localFilePath: json['local_file_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagem_url': imagemUrl,
      'descricao': descricao,
      // Guarda o caminho local no cache
      'local_file_path': localFilePath,
    };
  }
  // --- FIM DA CORREÇÃO ---
}
