import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../shared/widgets/rounded_group.dart';

/// Open source licenses in the app's own design.
///
/// Flutter's built-in `showLicensePage` brings its own Material chrome, which
/// looks like a different app; this reads the same registry and renders it as
/// the rounded groups used everywhere else.
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  /// Package name → its license paragraphs.
  final Map<String, List<String>> _byPackage = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs.map((p) => p.text).join('\n\n');
      for (final package in entry.packages) {
        _byPackage.putIfAbsent(package, () => []).add(text);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final packages = _byPackage.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Licenses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24.0),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(
                    '${AppConstants.appName} ${AppConstants.appVersion} — '
                    '${packages.length} open source packages.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                RoundedGroup(
                  children: [
                    for (final package in packages)
                      ListTile(
                        title: Text(package),
                        subtitle: Text(
                          '${_byPackage[package]!.length} license'
                          '${_byPackage[package]!.length == 1 ? '' : 's'}',
                        ),
                        trailing: Icon(
                          MdiIcons.chevronRight,
                          color: AppColors.textSecondary,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _LicenseDetailPage(
                              package: package,
                              texts: _byPackage[package]!,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  final String package;
  final List<String> texts;

  const _LicenseDetailPage({required this.package, required this.texts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(package)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppShapes.listInset,
          4,
          AppShapes.listInset,
          24.0,
        ),
        children: [
          for (var i = 0; i < texts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
              child: Material(
                color: AppColors.surface,
                borderRadius: AppShapes.row(
                  isFirst: i == 0,
                  isLast: i == texts.length - 1,
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    texts[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                      fontFamily: kIsWeb ? null : 'monospace',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
