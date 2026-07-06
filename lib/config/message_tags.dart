import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gotowe propozycje etykiet (prywatne per użytkownik, jak w Gmailu).
const List<String> suggestedMessageTags = [
  'szkoła',
  'zdrowie',
  'finanse',
];

String normalizeMessageTag(String raw) {
  return raw.trim().toLowerCase();
}

bool isSuggestedMessageTag(String tag) {
  return suggestedMessageTags.contains(normalizeMessageTag(tag));
}

String messageTagDisplayLabel(String tag) {
  final normalized = normalizeMessageTag(tag);
  if (normalized.isEmpty) {
    return tag;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

Color messageTagColor(String tag) {
  switch (normalizeMessageTag(tag)) {
    case 'szkoła':
      return const Color(0xFF1A73E8);
    case 'zdrowie':
      return const Color(0xFFD93025);
    case 'finanse':
      return const Color(0xFF188038);
    default:
      return AppTheme.purpleColor;
  }
}

List<String> sortedMessageTags(Iterable<String> tags) {
  final unique = tags.map(normalizeMessageTag).where((tag) => tag.isNotEmpty).toSet();
  final suggested = suggestedMessageTags.where(unique.contains).toList();
  final custom = unique.where((tag) => !isSuggestedMessageTag(tag)).toList()..sort();
  return [...suggested, ...custom];
}

List<String> customMessageTags(Iterable<String> tags) {
  return tags
      .map(normalizeMessageTag)
      .where((tag) => tag.isNotEmpty && !isSuggestedMessageTag(tag))
      .toSet()
      .toList()
    ..sort();
}
