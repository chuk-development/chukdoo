import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/rounded_group.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_sheets.dart';
import '../widgets/settings_tiles.dart';

/// Density and naming of the task lists.
class TasksSettingsPage extends ConsumerWidget {
  const TasksSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsSubPage(
      title: 'Tasks',
      children: [
        const SettingsSectionHeader('List'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.formatListChecks,
              title: 'Name of the main list',
              value: settings.mainListName,
              onTap: () async {
                final name = await showTextSheet(
                  context: context,
                  title: 'Main list',
                  message: 'The list every task without a project lands in.',
                  label: 'Name',
                  hint: 'Aufgaben',
                  confirmLabel: 'Save',
                  initialValue: settings.mainListName,
                );
                if (name != null) notifier.setMainListName(name);
              },
            ),
          ],
        ),

        const SettingsSectionHeader('Density'),
        RoundedGroup(children: [_RowSizeTile(size: settings.checkboxSize)]),
        SettingsFootnote(
          'Rows are ${settings.checkboxSize.label.toLowerCase()}: '
          '${settings.checkboxSize.circle.toStringAsFixed(0)} px circle, '
          '${settings.checkboxSize.rowPadding.toStringAsFixed(0)} px padding.',
        ),
      ],
    );
  }
}

/// Three-step slider instead of a yes/no switch: small fits more tasks on
/// screen, large gives a bigger tap target, medium is the default look.
class _RowSizeTile extends ConsumerWidget {
  final CheckboxSize size;

  const _RowSizeTile({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.checkCircleOutline, color: AppColors.textPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Task row size',
                  style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
              Text(
                size.label,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          Slider(
            value: size.index.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            label: size.label,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setCheckboxSize(CheckboxSize.values[value.round()]),
          ),
        ],
      ),
    );
  }
}
