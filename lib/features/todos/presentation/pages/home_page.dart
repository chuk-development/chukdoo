import 'package:flutter/material.dart';

import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/sync_error_banner.dart';
import 'inbox_page.dart';
import 'today_page.dart';
import 'upcoming_page.dart';
import '../../../projects/presentation/pages/browse_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  NavTab _currentTab = NavTab.inbox;

  Widget _buildBody() {
    switch (_currentTab) {
      case NavTab.inbox:
        return const InboxPage();
      case NavTab.today:
        return const TodayPage();
      case NavTab.upcoming:
        return const UpcomingPage();
      case NavTab.browse:
        return const BrowsePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Sync status banner (shows when offline)
          const SyncErrorBanner(),
          // Main content
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: ChukdooBottomNavBar(
        currentTab: _currentTab,
        onTabSelected: (tab) {
          setState(() {
            _currentTab = tab;
          });
        },
      ),
    );
  }
}
