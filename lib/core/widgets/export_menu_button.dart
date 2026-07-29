import 'package:flutter/material.dart';

import '../error/app_logger.dart';
import '../error/user_facing_error.dart';

/// Shared "Export" AppBar action for dashboards that offer both a CSV
/// (raw data) and a formatted-PDF export — see `ReportExportService`.
/// Handles the in-flight spinner and error snackbar itself so each call
/// site only has to supply the two export callbacks.
class ExportMenuButton extends StatefulWidget {
  const ExportMenuButton({super.key, required this.onExportCsv, required this.onExportPdf});

  final Future<void> Function() onExportCsv;
  final Future<void> Function() onExportPdf;

  @override
  State<ExportMenuButton> createState() => _ExportMenuButtonState();
}

class _ExportMenuButtonState extends State<ExportMenuButton> {
  bool _exporting = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _exporting = true);
    try {
      await action();
    } catch (error, stackTrace) {
      AppLogger.error('ExportMenuButton', 'export failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: ${UserFacingError.describe(error)}')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exporting) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Export',
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(value: () => _run(widget.onExportCsv), child: const Text('Export CSV')),
        PopupMenuItem(value: () => _run(widget.onExportPdf), child: const Text('Export PDF')),
      ],
    );
  }
}
