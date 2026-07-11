import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/models.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/calendar_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/calendar_date_utils.dart';
import '../../../../utils/app_browser_back.dart';
import '../../../screens/calendar/calendar_screen.dart';
import '../../../screens/messaging/messaging_screen.dart';

import 'mood_button.dart';

class ChildListItem {
  final String id;
  String text;
  bool checked;

  ChildListItem({
    required this.id,
    required this.text,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
      };

  factory ChildListItem.fromJson(Map<String, dynamic> json) {
    return ChildListItem(
      id: json['id'] as String,
      text: json['text'] as String,
      checked: json['checked'] as bool? ?? false,
    );
  }
}

class ChildTodoList {
  final String id;
  String title;
  final List<ChildListItem> items;

  ChildTodoList({
    required this.id,
    required this.title,
    List<ChildListItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory ChildTodoList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return ChildTodoList(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Lista',
      items: rawItems
          .map(
            (entry) => ChildListItem.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }
}
