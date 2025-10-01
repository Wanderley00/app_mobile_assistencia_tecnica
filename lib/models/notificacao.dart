// lib/models/notificacao.dart

class Notificacao {
  final int id;
  final String mensagem;
  final String? link;
  final bool lida;
  final DateTime dataCriacao;

  Notificacao({
    required this.id,
    required this.mensagem,
    this.link,
    required this.lida,
    required this.dataCriacao,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    return Notificacao(
      id: json['id'],
      mensagem: json['mensagem'] ?? 'Mensagem indisponível',
      link: json['link'],
      lida: json['lida'] ?? false,
      dataCriacao: DateTime.parse(json['data_criacao']),
    );
  }
}
