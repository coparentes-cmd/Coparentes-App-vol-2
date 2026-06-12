import 'package:flutter/material.dart';

import '../data/repositories/export_repository.dart';
import '../models/models.dart';
import '../services/export_pdf_service.dart';
import '../utils/file_download.dart';

class ExportsProvider extends ChangeNotifier {
  final ExportRepository _repository;

  ExportsProvider({required ExportRepository repository})
      : _repository = repository;

  final List<ExportJob> _jobs = [];
  bool _isLoading = false;
  String? _error;

  List<ExportJob> get jobs => List.unmodifiable(_jobs);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadExports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final jobs = await _repository.getExports();
      _jobs
        ..clear()
        ..addAll(jobs);
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ExportJob?> createExport({
    required ExportType type,
    required DateTime fromDate,
    required DateTime toDate,
    String? threadId,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final job = await _repository.createExport(
        type: type,
        fromDate: fromDate,
        toDate: toDate,
        threadId: threadId,
      );
      _jobs.insert(0, job);
      notifyListeners();
      return job;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> downloadExport(String exportId) async {
    _error = null;
    notifyListeners();

    try {
      return await _repository.downloadExport(exportId);
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> saveExportAsPdf(ExportJob job) async {
    _error = null;
    notifyListeners();

    if (job.status != 'completed') {
      _error = 'Eksport nie jest jeszcze gotowy.';
      notifyListeners();
      return false;
    }

    Map<String, dynamic>? data = await downloadExport(job.id);
    if (data == null && job.id.startsWith('export_demo_')) {
      data = ExportPdfService.demoDownloadPayload(job);
      _error = null;
    }

    if (data == null || data['payload'] == null) {
      _error ??= 'Nie udało się pobrać danych eksportu.';
      notifyListeners();
      return false;
    }

    try {
      final bytes = await ExportPdfService.buildPdf(data);
      await saveBytesAsFile(
        fileName: ExportPdfService.fileNameForJob(job),
        mimeType: 'application/pdf',
        bytes: bytes,
      );
      return true;
    } catch (error) {
      _error = 'Nie udało się zapisać PDF: $error';
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _jobs.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void initializeSampleData() {
    _jobs.clear();
    _error = null;
    _isLoading = false;

    final now = DateTime.now();
    _jobs.addAll([
      ExportJob(
        id: 'export_demo_001',
        type: ExportType.messages,
        fromDate: now.subtract(const Duration(days: 90)),
        toDate: now,
        status: 'completed',
        manifestHash: 'sha256_export_demo_001',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      ExportJob(
        id: 'export_demo_002',
        type: ExportType.fullPack,
        fromDate: now.subtract(const Duration(days: 30)),
        toDate: now,
        status: 'queued',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ]);
    notifyListeners();
  }
}
