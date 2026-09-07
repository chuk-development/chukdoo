import 'package:flutter/material.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/entity_edit_sheet.dart';
import 'calendar_style.dart';

/// The palette a calendar, a feed or an event can be painted with.
///
/// It is only the shared [EntityFlushGrid] wrapped in an [AppField], so the
/// event editor paints its swatches with the exact same block, cell size and
/// selection ring as "New calendar" and "New project". The swatches used to be
/// a centred [Wrap] of fixed 46px dots, which is why the last dot of a row
/// never lined up with the right edge.
class ColorSwatchGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;

  const ColorSwatchGrid({
    super.key,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: AppField(
        label: 'Colour',
        child: EntityFlushGrid(
          count: CalendarStyle.eventColors.length,
          itemBuilder: (i, cell) {
            final color = CalendarStyle.eventColors[i];
            return EntitySwatch(
              color: color,
              size: cell,
              selected: selected == color.toARGB32(),
              onTap: () => onPick(color.toARGB32()),
            );
          },
        ),
      ),
    );
  }
}
