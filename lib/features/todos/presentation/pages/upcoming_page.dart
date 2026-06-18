import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_swipe_tile.dart';
import '../widgets/quick_add_fab.dart';

class UpcomingPage extends ConsumerStatefulWidget {
  final VoidCallback? onMenu;

  const UpcomingPage({super.key, this.onMenu});

  @override
  ConsumerState<UpcomingPage> createState() => _UpcomingPageState();
}

class _UpcomingPageState extends ConsumerState<UpcomingPage> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  late DateTime _listStartDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekStart = _getWeekStart(_selectedDate);
    _listStartDate = _weekStart;
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _goToPreviousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _listStartDate = _weekStart;
      _selectedDate = _weekStart;
    });
  }

  void _goToNextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _listStartDate = _weekStart;
      _selectedDate = _weekStart;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = now;
      _weekStart = _getWeekStart(now);
      _listStartDate = _weekStart;
    });
  }

  void _showAddTodoSheet({DateTime? forDate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoInputSheet(
        defaultDueDate: forDate,
        onSubmit: (title, dueDate, dueTime, priority, projectId, labels, pinned) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            dueDate: dueDate ?? forDate,
            dueTime: dueTime,
            projectId: projectId,
            priority: priority != null
                ? TodoPriority.fromValue(priority)
                : TodoPriority.p4,
            labelIds: labels,
            isPinned: pinned,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final monthFormat = DateFormat('MMMM yyyy', 'en_US');
    final showCompleted = todoState.showCompleted;
    final hasAnyCompleted = todoState.allCompletedTodos.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: widget.onMenu != null
            ? IconButton(icon: const Icon(SolarIconsOutline.hamburgerMenu), onPressed: widget.onMenu, tooltip: 'Menu')
            : null,
        title: const Text('Upcoming'),
        actions: [
          if (hasAnyCompleted)
            IconButton(
              icon: Icon(
                showCompleted ? SolarIconsBold.checkCircle : SolarIconsOutline.checkCircle,
                color: showCompleted ? AppColors.primary : null,
              ),
              onPressed: () {
                ref.read(todoProvider.notifier).toggleShowCompleted();
              },
              tooltip: showCompleted ? 'Hide completed' : 'Show completed',
            ),
        ],
      ),
      body: Column(
        children: [
          // Month selector with navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(SolarIconsOutline.altArrowLeft),
                  onPressed: _goToPreviousWeek,
                  tooltip: 'Previous week',
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _goToToday,
                    child: Text(
                      monthFormat.format(_weekStart),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(SolarIconsOutline.altArrowRight),
                  onPressed: _goToNextWeek,
                  tooltip: 'Next week',
                ),
              ],
            ),
          ),

          // Week calendar strip
          _buildWeekCalendar(),

          const Divider(height: 1),

          // Date list - show 14 days starting from week start
          Expanded(
            child: SlidableAutoCloseBehavior(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: 14, // Show 2 weeks
                itemBuilder: (context, index) {
                  final date = _listStartDate.add(Duration(days: index));
                  return _buildDateSection(date, todoState, settings.checkboxSize == CheckboxSize.large);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: QuickAddFab(
        onPressed: () => _showAddTodoSheet(),
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final days = ['M', 'D', 'M', 'D', 'F', 'S', 'S'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final date = _weekStart.add(Duration(days: index));
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Column(
              children: [
                Text(
                  days[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected && !isToday
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppColors.onPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.textSecondary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDateSection(DateTime date, TodoState todoState, bool largeCheckbox) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    String dateLabel;
    String? subLabel;

    final weekdayFormat = DateFormat('EEEE', 'en_US');
    final dateFormat = DateFormat('d MMM', 'en_US');

    if (targetDate == today) {
      dateLabel = weekdayFormat.format(date);
      subLabel = '${dateFormat.format(date)} • Today';
    } else if (targetDate == tomorrow) {
      dateLabel = weekdayFormat.format(date);
      subLabel = '${dateFormat.format(date)} • Tomorrow';
    } else {
      dateLabel = weekdayFormat.format(date);
      subLabel = dateFormat.format(date);
    }

    final todosForDate = todoState.todosForDate(date);
    final completedTodosForDate = todoState.completedTodosForDate(date);
    final showCompleted = todoState.showCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showAddTodoSheet(forDate: date),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: targetDate == today
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subLabel != null)
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  SolarIconsOutline.addCircle,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        // Todos for this date
        ...todosForDate.map((todo) => _buildTodoTile(todo, largeCheckbox)),
        // Completed todos for this date
        if (showCompleted && completedTodosForDate.isNotEmpty)
          ...completedTodosForDate.map((todo) => _buildTodoTile(todo, largeCheckbox, isCompleted: true)),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildTodoTile(Todo todo, bool largeCheckbox, {bool isCompleted = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: TodoSwipeTile(
        key: ValueKey(todo.id),
        todo: todo,
        largeCheckbox: largeCheckbox,
        isCompleted: isCompleted,
      ),
    );
  }
}
