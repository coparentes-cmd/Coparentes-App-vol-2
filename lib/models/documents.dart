class FamilyDocument {
  static const privateCategory = 'Private';

  final String id;
  final String title;
  final String category;
  final String? childId;
  final String? childName;
  final String? fileName;
  final String? mimeType;
  final String? fileUrl;
  final String? uploadedById;
  final int sizeBytes;
  final bool hasFile;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyDocument({
    required this.id,
    required this.title,
    required this.category,
    this.childId,
    this.childName,
    this.fileName,
    this.mimeType,
    this.fileUrl,
    this.uploadedById,
    this.sizeBytes = 0,
    this.hasFile = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPrivate => category == privateCategory;
}

class EmailInvite {
  final String id;
  final String email;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  EmailInvite({
    required this.id,
    required this.email,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.acceptedAt,
  });
}

class EmailInviteSendResult {
  final EmailInvite invite;
  final bool emailSent;
  final String? inviteCode;

  EmailInviteSendResult({
    required this.invite,
    required this.emailSent,
    this.inviteCode,
  });
}
