// lib/screens/pdf_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart'; // 1. IMPORTE O PACOTE SHARE_PLUS

class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen(
      {super.key, required this.filePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // --- 2. ADICIONE O BOTÃO DE COMPARTILHAMENTO AQUI ---
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () async {
              // Converte o caminho do arquivo (String) para um objeto XFile
              final fileToShare = XFile(filePath);

              // Chama a função de compartilhamento do pacote
              await Share.shareXFiles(
                [fileToShare],
                text:
                    'Relatório de Campo: $title', // Texto que acompanha o anexo
                subject: 'Relatório de Campo: $title', // Assunto para e-mails
              );
            },
          ),
        ],
        // --- FIM DA ADIÇÃO ---
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: true,
        onError: (error) {
          print(error.toString());
        },
        onPageError: (page, error) {
          print('$page: ${error.toString()}');
        },
      ),
    );
  }
}
