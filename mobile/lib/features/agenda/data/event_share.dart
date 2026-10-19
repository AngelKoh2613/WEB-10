import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:secureplan_mobile/features/agenda/domain/agenda_event.dart';
import 'package:secureplan_mobile/features/agenda/domain/export_strategy.dart';

Future<void> shareEvents(
  EventExportStrategy strategy,
  List<AgendaEvent> events,
) {
  return writeExport(
    strategy: strategy,
    events: events,
    write: (bytes, fileName) async {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}$fileName',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: strategy.extensionName == 'json'
                  ? 'application/json'
                  : 'text/csv',
              name: fileName,
            ),
          ],
        ),
      );
    },
  );
}
