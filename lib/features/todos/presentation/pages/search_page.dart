import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_swipe_tile.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/theme/app_shapes.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Todo> _filterTodos(List<Todo> todos) {
    if (_query.isEmpty) return [];
    final queryLower = _query.toLowerCase();
    return todos.where((todo) {
      return todo.title.toLowerCase().contains(queryLower) ||
          (todo.description?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final filteredTodos = _filterTodos(todoState.todos);

    return AppScaffold(
  onBack: () => Navigator.pop(context),
  titleWidget: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Search tasks...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
        ),
  actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(MdiIcons.closeCircleOutline),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
            ),
        ],
  body: _query.isEmpty
          ? _buildEmptySearch()
          : filteredTodos.isEmpty
              ? _buildNoResults()
              : SlidableAutoCloseBehavior(
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: AppShapes.contentBottom(context)),
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = filteredTodos[index];
                      return _buildTodoItem(context, ref, todo, settings.checkboxSize,
                          isFirst: index == 0, isLast: index == filteredTodos.length - 1);
                    },
                  ),
                ),
);
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, CheckboxSize size,
      {bool isFirst = true, bool isLast = true}) {
    return TodoSwipeTile(
      key: ValueKey(todo.id),
      todo: todo,
      size: size,
      isCompleted: todo.isCompleted,
      isFirst: isFirst,
      isLast: isLast,
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.magnify,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Search tasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a search term to find your tasks',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.magnify,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tasks found for "$_query"',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
