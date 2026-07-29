import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../tenant/tenant_config.dart';

final reportExportServiceProvider = Provider<ReportExportService>((ref) => ReportExportService());

/// Shared export path for every dashboard's "Export" action (Usage
/// Dashboard, RCPA Dashboard, Team Targets, ...) — CSV for raw
/// data (import into a spreadsheet/accounting tool), a simple tabular PDF
/// for a formatted, shareable report. Both hand off to the OS share sheet
/// (via `share_plus`/`printing`) rather than writing to app storage — this
/// app doesn't otherwise touch the filesystem for user-facing files, and a
/// share sheet lets the admin save, email, or print without this app
/// needing platform-specific storage permissions.
class ReportExportService {
  /// [headers] and each row in [rows] must be the same length; values are
  /// stringified with `toString()` (already-formatted strings in, e.g. a
  /// pre-formatted date or amount, rather than raw `DateTime`/`double`, is
  /// the caller's job — this service doesn't know what a given column
  /// means).
  Future<void> exportCsv({
    required String filename,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) async {
    debugPrint('ReportExportService.exportCsv: filename=$filename rows=${rows.length}');
    final csvString = const ListToCsvConverter().convert([headers, ...rows]);
    final bytes = Uint8List.fromList(utf8.encode(csvString));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
      subject: filename,
    ));
  }

  /// A simple one-table PDF report: [title] as a heading (tenant name
  /// prefixed, so a shared/printed report is self-identifying), then
  /// [headers]/[rows] as a table. For anything more elaborate than a
  /// single table, build a `pw.Document` directly and call [sharePdf]
  /// instead of this.
  Future<void> exportSimpleTablePdf({
    required String filename,
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    debugPrint('ReportExportService.exportSimpleTablePdf: filename=$filename rows=${rows.length}');
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, text: '${currentTenant.appName} — $title'),
          pw.Text('Generated ${DateTime.now().toLocal()}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(headers: headers, data: rows),
        ],
      ),
    );
    await sharePdf(bytes: await document.save(), filename: filename);
  }

  /// Escape hatch for a caller that needs more than
  /// [exportSimpleTablePdf]'s single table (e.g. a multi-section report).
  Future<void> sharePdf({required Uint8List bytes, required String filename}) {
    debugPrint('ReportExportService.sharePdf: filename=$filename bytes=${bytes.length}');
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
