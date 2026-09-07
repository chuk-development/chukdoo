import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/app_drawer_panel.dart';

/// Side panel of the notes section.
class NotesDrawer extends ConsumerWidget {
  const NotesDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDrawerPanel(
      title: 'Notes',
      header: [
        AppDrawerTile(
          icon: MdiIcons.noteMultipleOutline,
          label: 'All notes',
          isSelected: true,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
