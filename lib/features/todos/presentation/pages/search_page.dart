import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_swipe_tile.dart';

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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(SolarIconsOutline.altArrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Aufgaben suchen...',
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
              icon: const Icon(SolarIconsOutline.closeCircle),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? _buildEmptySearch()
          : filteredTodos.isEmpty
              ? _buildNoResults()
              : SlidableAutoCloseBehavior(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todo = filteredTodos[index];
                      return _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large);
                    },
                  ),
                ),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, bool largeCheckbox) {
    return TodoSwipeTile(
      todo: todo,
      largeCheckbox: largeCheckbox,
      isCompleted: todo.isCompleted,
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
              SolarIconsOutline.magnifier,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aufgaben suchen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gib einen Suchbegriff ein, um deine Aufgaben zu finden',
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
              SolarIconsOutline.magnifier,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keine Ergebnisse',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keine Aufgaben gefunden für "$_query"',
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
