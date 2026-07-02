import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/enums.dart';
import '../lists/list_scaffold.dart';
import '../lists/todo_row.dart';

class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final project = ref.watch(taskByIdProvider(projectId)).value;
    final children =
        ref.watch(projectChildrenProvider(projectId)).value ?? [];
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final todos = children.where((t) => t.type == ItemType.todo).toList();
    final open = todos.where((t) => t.status == ItemStatus.open).toList();
    final done = todos.length - open.length;
    final progress = todos.isEmpty ? 0.0 : done / todos.length;

    // Order: loose to-dos first, then each heading followed by its
    // children — all already sorted by orderIndex.
    final headings =
        children.where((t) => t.type == ItemType.heading).toList();
    final looseTodos = open.where((t) => t.headingId == null).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => quickCreate(ref,
            create: () => ref
                .read(taskRepositoryProvider)
                .createTodo(projectId: projectId)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                OtSpacing.xl, OtSpacing.xl, OtSpacing.xl, OtSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  ProgressPie(progress: progress, size: 22),
                  const SizedBox(width: OtSpacing.md),
                  Expanded(
                    child: Text(
                        project.title.isEmpty ? 'New Project' : project.title,
                        style: theme.textTheme.headlineMedium),
                  ),
                  IconButton(
                    tooltip: 'Complete project',
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    onPressed: () =>
                        ref.read(taskRepositoryProvider).complete(projectId),
                  ),
                ],
              ),
            ),
          ),
          if (project.notes.trim().isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: OtSpacing.xl),
              sliver: SliverToBoxAdapter(
                child:
                    Text(project.notes, style: theme.textTheme.bodyMedium),
              ),
            ),
          SliverTodoList(children: [for (final t in looseTodos) TodoRow(task: t)]),
          for (final heading in headings) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: OtSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: ListSectionHeader(
                    label: heading.title, color: theme.colorScheme.primary),
              ),
            ),
            SliverTodoList(children: [
              for (final t in open.where((t) => t.headingId == heading.id))
                TodoRow(task: t),
            ]),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
        ],
      ),
    );
  }
}

/// The circular progress "pie" that fills as project to-dos complete.
class ProgressPie extends StatelessWidget {
  const ProgressPie({super.key, required this.progress, this.size = 20});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _PiePainter(value, color),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = color;
    canvas.drawCircle(center, radius - 0.9, ring);

    if (progress > 0) {
      final fill = Paint()..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3.5),
        -math.pi / 2,
        2 * math.pi * progress,
        true,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.progress != progress || old.color != color;
}
