import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import '../features/lists/magic_plus.dart';
import '../features/project/project_screen.dart';
import '../features/quick_entry/quick_entry.dart';
import '../features/shortcuts/app_shortcuts.dart';
import '../features/sync/sync_sheet.dart';
import '../integrations/global_hotkey_service.dart';
import 'built_in_lists.dart';
import 'providers.dart';

/// Breakpoint above which we show the persistent sidebar instead of
/// bottom navigation.
const _kSidebarBreakpoint = 700.0;

/// Adaptive navigation shell: persistent sidebar on desktop/web/tablet,
/// bottom navigation + drawer on phones.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  GlobalHotkeyService? _hotkeys;

  @override
  void initState() {
    super.initState();
    // OS-global Quick Entry hotkey on desktop.
    _hotkeys = GlobalHotkeyService(() async {
      if (mounted) await showQuickEntry(context, ref);
    })
      ..init();
  }

  @override
  void dispose() {
    _hotkeys?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Arm the reminder scheduler and Android share-target listener.
    ref.watch(notificationServiceProvider);
    ref.watch(shareIntentServiceProvider);
    // Keep the Android home-screen widget in sync with Today.
    ref.listen(todayProvider, (previous, next) {
      final view = next.value;
      if (view != null) {
        ref.read(todayWidgetServiceProvider).update(view);
      }
    });
    final wide = MediaQuery.sizeOf(context).width >= _kSidebarBreakpoint;
    return AppShortcuts(
      child: wide
          ? _WideShell(child: widget.child)
          : _NarrowShell(child: widget.child),
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: ColoredBox(
              color: isDark ? OtColors.darkSidebar : OtColors.lightSidebar,
              child: const Sidebar(),
            ),
          ),
          const VerticalDivider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    const tabs = [
      BuiltInList.inbox,
      BuiltInList.today,
      BuiltInList.upcoming,
      BuiltInList.anytime,
    ];
    final index = tabs.indexWhere((l) => location.startsWith(l.route));
    return Scaffold(
      drawer: const Drawer(child: SafeArea(child: Sidebar())),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 1 : index,
        onDestinationSelected: (i) => context.go(tabs[i].route),
        destinations: [
          for (final list in tabs)
            NavigationDestination(
              icon: Icon(list.icon, color: list.color),
              label: list.title,
            ),
        ],
      ),
    );
  }
}

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final areas = ref.watch(areasProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    final inboxCount = ref.watch(inboxCountProvider).value ?? 0;
    final todayCount = ref.watch(todayCountProvider).value ?? 0;

    int? countFor(BuiltInList list) => switch (list) {
          BuiltInList.inbox => inboxCount == 0 ? null : inboxCount,
          BuiltInList.today => todayCount == 0 ? null : todayCount,
          _ => null,
        };

    final looseProjects =
        projects.where((p) => p.areaId == null).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: OtSpacing.lg),
            children: [
              for (final list in BuiltInList.values) ...[
                if (list == BuiltInList.inbox)
                  // Dropping the Magic Plus on Inbox captures a to-do
                  // there, like Things.
                  DragTarget<MagicPlusPayload>(
                    onAcceptWithDetails: (_) async {
                      final task = await ref
                          .read(taskRepositoryProvider)
                          .createTodo();
                      ref
                          .read(expandedTaskIdProvider.notifier)
                          .set(task.id);
                      if (context.mounted) context.go(list.route);
                    },
                    builder: (context, candidates, rejected) => _SidebarTile(
                      icon: list.icon,
                      iconColor: list.color,
                      label: list.title,
                      count: countFor(list),
                      selected: location == list.route ||
                          candidates.isNotEmpty,
                      onTap: () => context.go(list.route),
                    ),
                  )
                else
                  _SidebarTile(
                    icon: list.icon,
                    iconColor: list.color,
                    label: list.title,
                    count: countFor(list),
                    selected: location == list.route,
                    onTap: () => context.go(list.route),
                  ),
                if (list == BuiltInList.inbox ||
                    list == BuiltInList.someday)
                  const SizedBox(height: OtSpacing.lg),
              ],
              const SizedBox(height: OtSpacing.lg),
              // ---- Projects without an area ----
              for (final project in looseProjects)
                _SidebarTile(
                  icon: Icons.donut_large_rounded,
                  iconColor: OtColors.accent,
                  label: project.title.isEmpty ? 'New Project' : project.title,
                  selected: location == '/project/${project.id}',
                  onTap: () => context.go('/project/${project.id}'),
                ),
              // ---- Areas with their projects ----
              for (final area in areas) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      OtSpacing.lg, OtSpacing.lg, OtSpacing.lg, OtSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.tag_rounded,
                          size: 14, color: OtColors.anytimeTeal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          area.title.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final project
                    in projects.where((p) => p.areaId == area.id))
                  _SidebarTile(
                    icon: Icons.donut_large_rounded,
                    iconColor: OtColors.accent,
                    label:
                        project.title.isEmpty ? 'New Project' : project.title,
                    selected: location == '/project/${project.id}',
                    onTap: () => context.go('/project/${project.id}'),
                  ),
              ],
            ],
          ),
        ),
        const Divider(),
        // ---- New list + sync status ----
        Padding(
          padding: const EdgeInsets.all(OtSpacing.sm),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => _showNewListMenu(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New List'),
              ),
              const Spacer(),
              const SyncStatusButton(),
            ],
          ),
        ),
      ],
    );
  }

  void _showNewListMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.donut_large_rounded, color: OtColors.accent),
              title: const Text('New Project'),
              subtitle: const Text('Define a goal, then work toward it'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final project =
                    await ref.read(taskRepositoryProvider).createProject();
                if (context.mounted) context.go('/project/${project.id}');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.tag_rounded, color: OtColors.anytimeTeal),
              title: const Text('New Area'),
              subtitle: const Text('Group projects by sphere of life'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _promptNewArea(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptNewArea(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Area'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Work, Family'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      await ref.read(areaRepositoryProvider).create(title.trim());
    }
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: OtSpacing.sm, vertical: OtSpacing.xxs),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OtRadii.sm)),
        selected: selected,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(label,
            style: theme.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: count == null
            ? null
            : Text('$count', style: theme.textTheme.bodyMedium),
        onTap: onTap,
      ),
    );
  }
}

/// Route helper used by the router for project pages.
Widget projectPage(String id) => ProjectScreen(projectId: id);
