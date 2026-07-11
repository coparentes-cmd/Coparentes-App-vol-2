import '../../models/models.dart';

/// Whether the user can compose and send messages in messaging UI.
bool canSendMessages(AppUser? user) {
  if (user == null) {
    return false;
  }
  return user.role != UserRole.observer;
}

/// Whether the user can assign private tags to messages.
bool canUsePrivateTags(AppUser? user) {
  if (user == null) {
    return false;
  }
  switch (user.role) {
    case UserRole.parentA:
    case UserRole.parentB:
      return true;
    case UserRole.child:
    case UserRole.observer:
      return false;
  }
}

/// Child accounts cannot create category channels via API (403) — use cache first.
bool shouldResolveChannelFromCache(AppUser? user) {
  return user?.role == UserRole.child;
}

/// Observer accounts are read-only in messaging.
bool isMessagingReadOnly(AppUser? user) {
  return user?.role == UserRole.observer;
}
