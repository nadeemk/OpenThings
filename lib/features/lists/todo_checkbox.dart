import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Things-style rounded-square checkbox with a satisfying pop animation.
///
/// The visual check state is optimistic: tapping flips it instantly so
/// the animation always plays, independent of when [onChanged]'s async
/// work (which may be deliberately delayed, e.g. to let the check
/// animation finish before a completed to-do leaves its list) actually
/// lands. If [checked] changes externally (sync from another device,
/// undo elsewhere) the visual follows it.
class TodoCheckbox extends StatefulWidget {
  const TodoCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.size = 18,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  State<TodoCheckbox> createState() => _TodoCheckboxState();
}

class _TodoCheckboxState extends State<TodoCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late bool _visualChecked = widget.checked;

  @override
  void didUpdateWidget(covariant TodoCheckbox old) {
    super.didUpdateWidget(old);
    // Only follow external changes, not the optimistic flip we already
    // applied locally on tap.
    if (widget.checked != old.checked && widget.checked != _visualChecked) {
      setState(() => _visualChecked = widget.checked);
      if (widget.checked) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    final next = !_visualChecked;
    setState(() => _visualChecked = next);
    if (next) _pop.forward(from: 0);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final border = theme.brightness == Brightness.dark
        ? OtColors.darkTextSecondary
        : const Color(0xFFC7C7CC);

    return Semantics(
      button: true,
      checked: _visualChecked,
      label: _visualChecked ? 'Mark as open' : 'Mark as completed',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ScaleTransition(
            // Brief pop when checked: 1.0 -> 1.25 -> 1.0.
            scale: TweenSequence<double>([
              TweenSequenceItem(
                  tween: Tween(begin: 1.0, end: 1.25), weight: 1),
              TweenSequenceItem(
                  tween: Tween(begin: 1.25, end: 1.0), weight: 1),
            ]).animate(
                CurvedAnimation(parent: _pop, curve: Curves.easeOutCubic)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _visualChecked ? 1 : 0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (context, t, _) => Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Color.lerp(border, accent, t)!,
                    width: 1.5,
                  ),
                  color: Color.lerp(Colors.transparent, accent, t),
                ),
                child: t > 0.4
                    ? Icon(Icons.check_rounded,
                        size: widget.size - 4, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
