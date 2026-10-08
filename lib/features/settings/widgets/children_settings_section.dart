import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'package:coparentes/l10n/app_strings.dart';
import 'action_tile.dart';

/// Nested children list inside workspace settings:
/// Dzieci → child name → Kopiuj / Edytuj / Usuń (and optional reset password).
class ChildrenSettingsSection extends StatefulWidget {
  final List<ChildProfile> children;
  final UserRole? userRole;
  final Color roleColor;
  final bool isDark;
  final GlobalKey? addChildKey;
  final VoidCallback? onAddChild;
  final void Function(ChildProfile child) onCopyInvite;
  final void Function(ChildProfile child) onEdit;
  final void Function(ChildProfile child) onDelete;
  final void Function(ChildProfile child)? onResetPassword;

  /// When true, the children list starts expanded (tests / deep-link).
  final bool initiallyExpanded;

  const ChildrenSettingsSection({
    super.key,
    required this.children,
    required this.userRole,
    required this.roleColor,
    required this.isDark,
    this.addChildKey,
    this.onAddChild,
    required this.onCopyInvite,
    required this.onEdit,
    required this.onDelete,
    this.onResetPassword,
    this.initiallyExpanded = false,
  });

  @override
  State<ChildrenSettingsSection> createState() =>
      ChildrenSettingsSectionState();
}

@visibleForTesting
class ChildrenSettingsSectionState extends State<ChildrenSettingsSection> {
  late bool _listExpanded;
  String? _expandedChildId;

  @override
  void initState() {
    super.initState();
    _listExpanded = widget.initiallyExpanded;
  }

  void _toggleList() {
    setState(() {
      _listExpanded = !_listExpanded;
      if (!_listExpanded) {
        _expandedChildId = null;
      }
    });
  }

  void _toggleChild(String childId) {
    setState(() {
      _expandedChildId = _expandedChildId == childId ? null : childId;
    });
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 52,
      color: widget.isDark ? Colors.white12 : AppTheme.dividerColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.userRole == UserRole.parentA &&
        widget.onAddChild != null;
    final hasChildren = widget.children.isNotEmpty;

    return Column(
      children: [
        if (hasChildren) ...[
          _divider(),
          _ExpandRow(
            key: const Key('children_section_header'),
            icon: Icons.child_care_outlined,
            label: context.tr('Dzieci'),
            subtitle: context.tr('Profile i status zaproszeń'),
            color: widget.roleColor,
            isDark: widget.isDark,
            expanded: _listExpanded,
            onTap: _toggleList,
          ),
          if (_listExpanded)
            ...widget.children.expand((child) {
              final status = child.linkedAccountId != null
                  ? context.tr('Dołączyło')
                  : context.tr('Oczekuje');
              final dob =
                  '${child.dateOfBirth.day.toString().padLeft(2, '0')}-'
                  '${child.dateOfBirth.month.toString().padLeft(2, '0')}-'
                  '${child.dateOfBirth.year}';
              final childExpanded = _expandedChildId == child.id;
              final tiles = <Widget>[
                _divider(),
                _ExpandRow(
                  key: Key('child_row_${child.id}'),
                  icon: Icons.child_care,
                  label: child.name,
                  subtitle: [
                    dob,
                    status,
                    if (child.inviteCode != null &&
                        child.inviteCode!.isNotEmpty)
                      'Kod: ${child.inviteCode}',
                  ].join(' · '),
                  color: widget.roleColor,
                  isDark: widget.isDark,
                  expanded: childExpanded,
                  onTap: () => _toggleChild(child.id),
                ),
              ];
              if (childExpanded) {
                if (child.inviteCode != null &&
                    child.inviteCode!.isNotEmpty) {
                  tiles.addAll([
                    _divider(),
                    ActionTile(
                      key: Key('child_copy_${child.id}'),
                      icon: Icons.copy_outlined,
                      label: context.tr('Kopiuj kod dziecka'),
                      color: widget.roleColor,
                      isDark: widget.isDark,
                      onTap: () => widget.onCopyInvite(child),
                    ),
                  ]);
                }
                tiles.addAll([
                  _divider(),
                  ActionTile(
                    key: Key('child_edit_${child.id}'),
                    icon: Icons.edit_outlined,
                    label: context.tr('Edytuj dziecko'),
                    color: widget.roleColor,
                    isDark: widget.isDark,
                    onTap: () => widget.onEdit(child),
                  ),
                ]);
                final linkedId = child.linkedAccountId;
                if (linkedId != null && widget.onResetPassword != null) {
                  tiles.addAll([
                    _divider(),
                    ActionTile(
                      key: Key('child_reset_${child.id}'),
                      icon: Icons.lock_reset_outlined,
                      label: context.tr('Zresetuj hasło logowania dziecka'),
                      subtitle: context.tr('Link na e-mail obojga rodziców'),
                      color: widget.roleColor,
                      isDark: widget.isDark,
                      onTap: () => widget.onResetPassword!(child),
                    ),
                  ]);
                }
                if (widget.userRole == UserRole.parentA) {
                  tiles.addAll([
                    _divider(),
                    ActionTile(
                      key: Key('child_delete_${child.id}'),
                      icon: Icons.delete_outline,
                      label: context.tr('Usuń profil dziecka'),
                      color: AppTheme.errorColor,
                      isDark: widget.isDark,
                      onTap: () => widget.onDelete(child),
                    ),
                  ]);
                }
              }
              return tiles;
            }),
        ],
        if (canAdd) ...[
          _divider(),
          KeyedSubtree(
            key: widget.addChildKey,
            child: ActionTile(
              key: const Key('add_child_tile'),
              icon: Icons.person_add_outlined,
              label: context.tr('Dodaj dziecko'),
              subtitle: !hasChildren
                  ? context.tr('Dodaj pierwszy profil dziecka')
                  : context.tr('Dodaj kolejny profil dziecka'),
              color: widget.roleColor,
              isDark: widget.isDark,
              onTap: widget.onAddChild,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExpandRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final bool isDark;
  final bool expanded;
  final VoidCallback onTap;

  const _ExpandRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.isDark,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final subColor = isDark ? Colors.white38 : AppTheme.textHint;
    final chevronColor = isDark ? Colors.white24 : AppTheme.textHint;

    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: subColor),
            )
          : null,
      trailing: AnimatedRotation(
        turns: expanded ? 0.25 : 0,
        duration: const Duration(milliseconds: 200),
        child: Icon(Icons.chevron_right, color: chevronColor, size: 18),
      ),
      onTap: onTap,
    );
  }
}
