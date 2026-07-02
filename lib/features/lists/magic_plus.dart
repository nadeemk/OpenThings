import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';

/// Payload carried while dragging the Magic Plus button.
class MagicPlusPayload {
  const MagicPlusPayload();
}

/// The Magic Plus button: tap to add at the end of the list; drag and
/// drop between rows to insert a to-do exactly there, like Things.
class MagicPlusFab extends StatelessWidget {
  const MagicPlusFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = Material(
      shape: const CircleBorder(),
      color: theme.colorScheme.primary,
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.add_rounded, size: 30, color: Colors.white),
        ),
      ),
    );

    return Draggable<MagicPlusPayload>(
      data: const MagicPlusPayload(),
      feedback: Opacity(opacity: 0.85, child: button),
      childWhenDragging: Opacity(opacity: 0.3, child: button),
      child: button,
    );
  }
}

/// Wraps a to-do row so the Magic Plus can be dropped onto its top
/// edge, inserting a new to-do right before it.
class MagicPlusDropTarget extends ConsumerStatefulWidget {
  const MagicPlusDropTarget({
    super.key,
    required this.child,
    required this.before,
    required this.onInsert,
  });

  final Widget child;

  /// The row this target sits above.
  final Task before;

  /// Called with the order index the new to-do should get.
  final Future<void> Function(double orderIndex) onInsert;

  @override
  ConsumerState<MagicPlusDropTarget> createState() =>
      _MagicPlusDropTargetState();
}

class _MagicPlusDropTargetState extends ConsumerState<MagicPlusDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<MagicPlusPayload>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (_) async {
        setState(() => _hovering = false);
        await widget.onInsert(widget.before.orderIndex - 0.5);
      },
      builder: (context, candidates, rejected) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: _hovering ? 3 : 0,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
