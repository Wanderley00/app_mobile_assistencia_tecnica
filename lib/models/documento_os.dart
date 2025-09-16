// lib/models/documento_os.dart

import 'tipo_documento.dart'; // Garanta que este import exista

class DocumentoOS {
  final int id;
  final String titulo;
  final TipoDocumento tipoDocumento; // MUDANÇA 1: O tipo agora é um objeto
  final String? arquivoUrl;
  final DateTime dataUpload;
  final String uploadedBy;
  final bool isPending;
  final String? localFilePath;

  DocumentoOS({
    required this.id,
    required this.titulo,
    required this.tipoDocumento, // MUDANÇA 2: Atualizado no construtor
    this.arquivoUrl,
    required this.dataUpload,
    required this.uploadedBy,
    this.isPending = false,
    this.localFilePath,
  });

  factory DocumentoOS.fromJson(Map<String, dynamic> json) {
    return DocumentoOS(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      titulo: json['titulo'] ?? 'N/A',
      // MUDANÇA 3: Agora usa o fromJson do modelo TipoDocumento
      tipoDocumento: TipoDocumento.fromJson(
          json['tipo_documento'] ?? {'id': 0, 'nome': 'N/A'}),
      arquivoUrl: json['arquivo_url'],
      dataUpload: DateTime.parse(json['data_upload']),
      uploadedBy: json['uploaded_by'] ?? 'N/A',
      isPending: false,
      localFilePath: json['local_file_path'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        // Ao salvar no cache, salvamos o objeto inteiro para consistência
        'tipo_documento': tipoDocumento.toJson(),
        'arquivo_url': arquivoUrl,
        'data_upload': dataUpload.toIso8601String(),
        'uploaded_by': uploadedBy,
        'isPending': isPending,
        'local_file_path': localFilePath,
      };

  DocumentoOS copyWith({
    int? id,
    String? titulo,
    TipoDocumento? tipoDocumento, // MUDANÇA 4: Atualizado no copyWith
    String? arquivoUrl,
    DateTime? dataUpload,
    String? uploadedBy,
    bool? isPending,
    String? localFilePath,
  }) {
    return DocumentoOS(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      arquivoUrl: arquivoUrl ?? this.arquivoUrl,
      dataUpload: dataUpload ?? this.dataUpload,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      isPending: isPending ?? this.isPending,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}
