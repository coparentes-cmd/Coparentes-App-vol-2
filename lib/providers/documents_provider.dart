import 'package:flutter/material.dart';

import '../data/api/app_api_client.dart';
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

  static String uploadErrorMessage(Object error) {
    if (error is ApiException) {
      switch (error.message) {
        case 'workspace_document_limit_reached':
          return 'Osiągnięto limit dokumentów dla tej rodziny (200 plików).';
        case 'workspace_storage_limit_reached':
          return 'Osiągnięto limit miejsca na dokumenty (100 MB). Usuń nieużywane pliki prywatne, aby zwolnić miejsce.';
        case 'file_too_large':
          return 'Plik jest za duży (max 5 MB).';
        case 'unsupported_file_type':
          return 'Nieobsługiwany typ pliku.';
        case 'file_required':
          return 'Dodaj plik dokumentu.';
      }
    }
    return 'Nie udało się dodać dokumentu.';
  }

  Future<void> load({String? viewerUserId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final documents = await _repository.getDocuments(viewerUserId: viewerUserId);
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
    String? fileName,
    String? contentBase64,
    String? mimeType,
    String? uploadedById,
  }) async {
    try {
      final created = await _repository.createDocument(
        title: title,
        category: category,
        childId: childId,
        fileName: fileName ?? title,
        mimeType: mimeType ?? 'application/octet-stream',
        contentBase64: contentBase64,
        uploadedById: uploadedById,
      );
      _documents.insert(0, created);
      _error = null;
      notifyListeners();
      return created;
    } catch (error) {
      _error = uploadErrorMessage(error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> downloadDocument(String documentId) async {
    try {
      return await _repository.downloadDocument(documentId);
    } catch (_) {
      _error = 'Nie udało się pobrać dokumentu.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      await _repository.deleteDocument(documentId);
      _documents.removeWhere((document) => document.id == documentId);
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Nie udało się usunąć dokumentu.';
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _documents.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
