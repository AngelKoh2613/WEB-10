import 'package:flutter/material.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';

const _categoryColors = {
  'personal': Color(0xFF2F6FDB),
  'trabajo': Color(0xFF1F8A5B),
  'estudio': Color(0xFF7A4CC2),
  'otro': Color(0xFFB06A00),
};

const _categoryIcons = {
  'personal': Icons.person_outline,
  'trabajo': Icons.work_outline,
  'estudio': Icons.school_outlined,
  'otro': Icons.label_outline,
};

const _priorityIcons = {
  'low': Icons.arrow_downward,
  'medium': Icons.remove,
  'high': Icons.priority_high,
};

Color categoryColor(String category) {
  return _categoryColors[category] ?? AppColors.muted;
}

IconData categoryIcon(String category) {
  return _categoryIcons[category] ?? Icons.label_outline;
}

IconData priorityIcon(String priority) {
  return _priorityIcons[priority] ?? Icons.remove;
}

class SyncStyle {
  const SyncStyle(this.icon, this.foreground, this.background);

  final IconData icon;
  final Color foreground;
  final Color background;
}

SyncStyle syncStyle(String status) {
  return switch (status) {
    'conflict' => const SyncStyle(
      Icons.sync_problem_outlined,
      AppColors.onErrorContainer,
      AppColors.errorContainer,
    ),
    'failed' => const SyncStyle(
      Icons.cloud_off_outlined,
      AppColors.onErrorContainer,
      AppColors.errorContainer,
    ),
    _ => const SyncStyle(
      Icons.cloud_upload_outlined,
      AppColors.warning,
      AppColors.warningContainer,
    ),
  };
}
