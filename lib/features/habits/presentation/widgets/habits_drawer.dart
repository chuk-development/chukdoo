import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/app_drawer_panel.dart';

/// Side panel of the habits section.
class HabitsDrawer extends ConsumerWidget {
  const HabitsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDrawerPanel(
      title: 'Habits',
      header: [
        AppDrawerTile(
          icon: MdiIcons.trophyOutline,
          label: 'All habits',
          isSelected: true,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
