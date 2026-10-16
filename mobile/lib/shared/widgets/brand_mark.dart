import 'package:flutter/material.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(
          Icons.event_note_rounded,
          size: size * 0.5,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
