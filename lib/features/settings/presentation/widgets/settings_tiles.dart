import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_scaffold.dart';

/// Small caps label above a [RoundedGroup] of settings rows.
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Frame of every settings sub-page: the app's page header with a back
/// chevron and a scrollable that clears the floating nav bar.
class SettingsSubPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSubPage({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    // A pushed page owns its background: [AppScaffold] paints none, so without
    // this the shell behind the route would shine through.
    return ColoredBox(
      color: AppColors.background,
      child: AppScaffold(
        title: title,
        onBack: () => Navigator.pop(context),
        body: ListView(
          padding: EdgeInsets.only(bottom: AppShapes.contentBottom(context)),
          children: children,
        ),
      ),
    );
  }
}

/// A row that opens something else — a sub-page or a picker sheet.
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Current value, shown at the right edge instead of a plain chevron only.
  final String? value;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(width: 4),
          Icon(MdiIcons.chevronRight, color: AppColors.textSecondary),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// An on/off row. Same metrics as [SettingsNavTile] so a group of both reads
/// as one block.
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textPrimary),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Explanation under a group — the place for "the calendar reads this on the
/// next start" style notes.
class SettingsFootnote extends StatelessWidget {
  final String text;

  const SettingsFootnote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    );
  }
}

/// `14:00` — the app writes hours the same way everywhere.
String formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

/// `1 h 30 min` — used for event length and reminder lead time.
String formatMinutes(int minutes) {
  if (minutes == 0) return 'At the event';
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return days == 1 ? '1 day' : '$days days';
  }
  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hour' : '$hours hours';
  }
  if (minutes > 60) {
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }
  return '$minutes min';
}

/// Same as [formatMinutes] but phrased as a lead time before an event.
String formatLeadTime(int? minutes) {
  if (minutes == null) return 'None';
  if (minutes == 0) return 'At the event';
  return '${formatMinutes(minutes)} before';
}

/// `07:05`, from minutes since midnight.
String formatTimeOfDay(int minutesSinceMidnight) {
  final h = (minutesSinceMidnight ~/ 60).toString().padLeft(2, '0');
  final m = (minutesSinceMidnight % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
