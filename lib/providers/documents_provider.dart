import 'package:flutter/material.dart';

import '../data/repositories/documents_repository.dart';
import '../models/models.dart';

class DocumentsProvider extends ChangeNotifier {
  final DocumentsRepository _repository;

  DocumentsProvider({required DocumentsRepository repository})
      : _repository = repository;

  final List<FamilyDocument> _documents = [];
  bool _isLoading = false;
  String? _error;

  List<FamilyDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final documents = await _repository.getDocuments();
      _documents
        ..clear()
        ..addAll(documents);
    } catch (_) {
      _error = 'Nie udało się pobrać dokumentów.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FamilyDocument?> uploadDocument({
    required String title,
    required String category,
    String? childId,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      final created = await _repository.createDocument(
        title: title,
        category: category,
        childId: childId,
        fileUrl: fileUrl,
        fileName: fileName ?? title,
        mimeType: 'application/octet-stream',
      );
      _documents.insert(0, created);
      notifyListeners();
      return created;
    } catch (_) {
      _error = 'Nie udało się dodać dokumentu.';
      notifyListeners();
      return null;
    }
  }

  void clear() {
    _documents.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
