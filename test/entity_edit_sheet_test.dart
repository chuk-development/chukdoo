import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:chukdoo/core/theme/app_colors.dart';
import 'package:chukdoo/shared/widgets/entity_edit_sheet.dart';

/// Projects, calendars, note folders and habits now share one form. A picture
/// shows that they look alike; only a test shows that the shared form still
/// reports the picked colour, the picked icon and the typed name.
void main() {
  final icons = <String, IconData>{
    'folder': MdiIcons.folder,
    'star': MdiIcons.star,
    'rocket': MdiIcons.rocketLaunch,
  };

  Future<void> pumpSheet(
    WidgetTester tester, {
    required ValueChanged<int> onColorChanged,
    required ValueChanged<String> onIconChanged,
    required ValueChanged<EntityEditValues> onSave,
    int? selectedColor,
    String selectedIcon = 'folder',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityEditSheet(
            title: 'New project',
            nameHint: 'Project name',
            secondLabel: 'Description',
            secondHint: 'Optional',
            colors: AppColors.projectColors,
            selectedColor:
                selectedColor ?? AppColors.projectColors.first.toARGB32(),
            onColorChanged: onColorChanged,
            icons: icons,
            selectedIcon: selectedIcon,
            onIconChanged: onIconChanged,
            saveLabel: 'Create',
            onSave: onSave,
          ),
        ),
      ),
    );
  }

  testWidgets('picking a colour and an icon reports them', (tester) async {
    int? pickedColor;
    String? pickedIcon;

    await pumpSheet(
      tester,
      onColorChanged: (c) => pickedColor = c,
      onIconChanged: (k) => pickedIcon = k,
      onSave: (_) {},
    );
    await tester.pumpAndSettle();

    // The third swatch of the shared palette.
    await tester.tap(find.byType(EntitySwatch).at(2));
    await tester.pump();
    expect(pickedColor, AppColors.projectColors[2].toARGB32());

    await tester.tap(find.byIcon(MdiIcons.rocketLaunch));
    await tester.pump();
    expect(pickedIcon, 'rocket');
  });

  testWidgets('Save is dead until a name is typed, then hands it back', (
    tester,
  ) async {
    EntityEditValues? saved;

    await pumpSheet(
      tester,
      onColorChanged: (_) {},
      onIconChanged: (_) {},
      onSave: (v) => saved = v,
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Create');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '  Garden  ');
    await tester.enterText(find.byType(TextField).last, 'Beds and pots');
    await tester.pump();

    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

    // The form scrolls, so the action can sit below the fold.
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump();

    expect(saved?.name, 'Garden');
    expect(saved?.description, 'Beds and pots');
  });

  testWidgets('a full row of the grid ends flush with the right edge', (
    tester,
  ) async {
    // The owner's complaint: the icons stopped short of the right edge because
    // the old Wrap used fixed cells. Here the cell comes from the constraints,
    // so the last item of a full row has to touch the block's right edge.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: EntityFlushGrid(
                count: 10,
                itemBuilder: (i, cell) => ColoredBox(
                  key: ValueKey(i),
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.getRect(find.byType(EntityFlushGrid));
    var flush = 0;
    for (var i = 0; i < 10; i++) {
      if ((tester.getRect(find.byKey(ValueKey(i))).right - grid.right).abs() <
          0.5) {
        flush++;
      }
    }

    // Ten items never divide into one row, so at least one row is full and
    // ends on the edge.
    expect(flush, greaterThan(0));
    expect(grid.width, 300);
  });
}
