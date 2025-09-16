// lib/widgets/info_row.dart

import 'package:flutter/material.dart';
import '../main.dart'; // Para AppTextStyles

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
