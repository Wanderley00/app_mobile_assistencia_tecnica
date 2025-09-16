// lib/models/categoria_problema.dart

import 'subcategoria_problema.dart';

class CategoriaProblema {
  final int id;
  final String nome;
  final List<SubcategoriaProblema> subcategorias;

  CategoriaProblema(
      {required this.id, required this.nome, required this.subcategorias});

  factory CategoriaProblema.fromJson(Map<String, dynamic> json) {
    var subList = json['subcategorias'] as List? ?? [];
    List<SubcategoriaProblema> subcategoriasList =
        subList.map((i) => SubcategoriaProblema.fromJson(i)).toList();
    return CategoriaProblema(
      id: json['id'],
      nome: json['nome'],
      subcategorias: subcategoriasList,
    );
  }
}
