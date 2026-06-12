import 'package:coparentes/models/models.dart';
import 'package:coparentes/services/export_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildPdf returns non-empty bytes for finance export', () async {
    final job = ExportJob(
      id: 'export_test',
      type: ExportType.finances,
      fromDate: DateTime(2026, 1, 1),
      toDate: DateTime(2026, 1, 31),
      status: 'completed',
      createdAt: DateTime(2026, 2, 1),
    );

    final payload = ExportPdfService.demoDownloadPayload(job);
    final bytes = await ExportPdfService.buildPdf(payload);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildPdf supports Polish characters in message export', () async {
    final job = ExportJob(
      id: 'export_test_pl',
      type: ExportType.messages,
      fromDate: DateTime(2026, 1, 1),
      toDate: DateTime(2026, 1, 31),
      status: 'completed',
      createdAt: DateTime(2026, 2, 1),
    );

    final payload = ExportPdfService.demoDownloadPayload(job);
    final bytes = await ExportPdfService.buildPdf(payload);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
