import '../../models/models.dart';

FamilyDocument familyDocumentFromJson(Map<String, dynamic> json) {
  return FamilyDocument(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    childId: json['childId'] as String?,
    childName: json['childName'] as String?,
    fileName: json['fileName'] as String?,
    mimeType: json['mimeType'] as String?,
    fileUrl: json['fileUrl'] as String?,
    uploadedById: json['uploadedBy'] as String? ?? json['uploadedById'] as String?,
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    hasFile: json['hasFile'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

Map<String, dynamic> familyDocumentToJson(FamilyDocument document) {
  return {
    'id': document.id,
    'title': document.title,
    'category': document.category,
    'childId': document.childId,
    'childName': document.childName,
    'fileName': document.fileName,
    'mimeType': document.mimeType,
    'fileUrl': document.fileUrl,
    'uploadedBy': document.uploadedById,
    'sizeBytes': document.sizeBytes,
    'hasFile': document.hasFile,
    'createdAt': document.createdAt.toIso8601String(),
    'updatedAt': document.updatedAt.toIso8601String(),
  };
}

List<FamilyDocument> filterDocumentsForViewer(
  List<FamilyDocument> documents,
  String? viewerUserId,
) {
  if (viewerUserId == null) {
    return documents;
  }

  return documents
      .where(
        (document) =>
            !document.isPrivate || document.uploadedById == viewerUserId,
      )
      .toList();
}

EmailInvite emailInviteFromJson(Map<String, dynamic> json) {
  return EmailInvite(
    id: json['id'] as String,
    email: json['email'] as String,
    status: json['status'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    acceptedAt: json['acceptedAt'] == null
        ? null
        : DateTime.parse(json['acceptedAt'] as String),
  );
}

Map<String, dynamic> emailInviteToJson(EmailInvite invite) {
  return {
    'id': invite.id,
    'email': invite.email,
    'status': invite.status,
    'expiresAt': invite.expiresAt.toIso8601String(),
    'createdAt': invite.createdAt.toIso8601String(),
    'acceptedAt': invite.acceptedAt?.toIso8601String(),
  };
}
