import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secureplan_mobile/core/di/app_providers.dart';
import 'package:secureplan_mobile/core/theme/app_theme.dart';
import 'package:secureplan_mobile/features/agenda/application/agenda_controller.dart';
import 'package:secureplan_mobile/features/agenda/data/event_share.dart';
import 'package:secureplan_mobile/features/agenda/domain/export_strategy.dart';
import 'package:secureplan_mobile/features/agenda/presentation/agenda_screen.dart';
import 'package:secureplan_mobile/features/auth/application/auth_controller.dart';
import 'package:secureplan_mobile/shared/widgets/brand_mark.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(appNameProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: AppSpacing.lg,
        title: Row(
          children: [
            const BrandMark(size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(appName, style: theme.textTheme.titleLarge),
                  Text(
                    'Tu agenda segura',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar',
            onPressed: () => _export(context, ref),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: const AgendaScreen(),
    );
  }
}

Future<void> _export(BuildContext context, WidgetRef ref) async {
  final choice = await showDialog<EventExportStrategy>(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: const Icon(Icons.ios_share_outlined),
        title: const Text('Exportar eventos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se exportan los eventos visibles de este mes, sin datos de sesión ni de sincronización.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _ExportOption(
              icon: Icons.data_object,
              label: 'JSON',
              detail: 'Copia completa y legible por otras aplicaciones',
              onTap: () => Navigator.of(context).pop(const JsonEventExporter()),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ExportOption(
              icon: Icons.table_chart_outlined,
              label: 'CSV',
              detail: 'Tabla para hojas de cálculo',
              onTap: () => Navigator.of(context).pop(const CsvEventExporter()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) {
    return;
  }
  final events = ref.read(agendaControllerProvider).asData?.value ?? const [];
  try {
    await shareEvents(choice, events);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El archivo se exportó')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo exportar el archivo')),
      );
    }
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: scheme.primary),
        title: Text(label),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
