import 'package:flutter/material.dart';

import 'app_color_scheme.dart';
import 'enums.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final bool twoFactorEnabled;
  final bool highConflictMode;
  final bool mustChangePassword;
  final ThemeMode themeMode;
  final AppColorScheme colorScheme;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.twoFactorEnabled = false,
    this.highConflictMode = false,
    this.mustChangePassword = false,
    this.themeMode = ThemeMode.light,
    this.colorScheme = AppColorScheme.teal,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    bool? twoFactorEnabled,
    bool? highConflictMode,
    bool? mustChangePassword,
    ThemeMode? themeMode,
    AppColorScheme? colorScheme,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      highConflictMode: highConflictMode ?? this.highConflictMode,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      themeMode: themeMode ?? this.themeMode,
      colorScheme: colorScheme ?? this.colorScheme,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Color get roleColor {
    switch (role) {
      case UserRole.parentA:
        return const Color(0xFF00897B);
      case UserRole.parentB:
        return const Color(0xFF1565C0);
      case UserRole.child:
        return const Color(0xFFF57C00);
      case UserRole.observer:
        return const Color(0xFF6A1B9A);
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.parentA:
        return 'Parent A';
      case UserRole.parentB:
        return 'Parent B';
      case UserRole.child:
        return 'Child';
      case UserRole.observer:
        return 'Observer';
    }
  }

  IconData get roleIcon {
    switch (role) {
      case UserRole.parentA:
        return Icons.person;
      case UserRole.parentB:
        return Icons.person_outline;
      case UserRole.child:
        return Icons.child_care;
      case UserRole.observer:
        return Icons.visibility;
    }
  }
}

class Workspace {
  final String id;
  final String name;
  final String? inviteCode;
  final String? childInviteCode;
  final DateTime? inviteCodeExpiresAt;
  final List<AppUser> members;
  final List<ChildProfile> children;
  final DateTime createdAt;

  Workspace({
    required this.id,
    required this.name,
    this.inviteCode,
    this.childInviteCode,
    this.inviteCodeExpiresAt,
    required this.members,
    required this.children,
    required this.createdAt,
  });
}

class ChildProfile {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String? school;

  /// Linked child [AppUser.id] after invite login; null if not joined yet.
  final String? linkedAccountId;

  ChildProfile({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    this.school,
    this.linkedAccountId,
  });

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
}
