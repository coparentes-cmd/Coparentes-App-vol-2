import 'package:flutter/material.dart';

import 'enums.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final bool twoFactorEnabled;
  final bool highConflictMode;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.twoFactorEnabled = false,
    this.highConflictMode = false,
    required this.createdAt,
  });

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

  ChildProfile({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    this.school,
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
