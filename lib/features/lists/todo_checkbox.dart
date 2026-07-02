import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Things-style rounded-square checkbox with a satisfying pop animation.
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

  @override
  void didUpdateWidget(covariant TodoCheckbox old) {
    super.didUpdateWidget(old);
    if (widget.checked && !old.checked) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final border = theme.brightness == Brightness.dark
        ? OtColors.darkTextSecondary
        : const Color(0xFFC7C7CC);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onChanged(!widget.checked),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ScaleTransition(
          // Brief pop when checked: 1.0 -> 1.25 -> 1.0.
          scale: TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 1),
            TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 1),
          ]).animate(
              CurvedAnimation(parent: _pop, curve: Curves.easeOutCubic)),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.checked ? 1 : 0),
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
    );
  }
}
