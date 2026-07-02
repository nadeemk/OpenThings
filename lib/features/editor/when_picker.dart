import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/db/enums.dart';
import '../../domain/dates.dart' as d;

/// Result of the When picker.
typedef WhenChoice = ({StartBucket bucket, DateTime? date, bool isEvening});

/// Things' "When" popover: Today / This Evening / Tomorrow / Someday /
/// a specific date / clear.
Future<WhenChoice?> showWhenPicker(BuildContext context) async {
  return showModalBottomSheet<WhenChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final today = d.today();
      void pick(WhenChoice c) => Navigator.of(context).pop(c);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.star_rounded, color: OtColors.todayYellow),
              title: const Text('Today'),
              onTap: () => pick(
                  (bucket: StartBucket.anytime, date: today, isEvening: false)),
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_round,
                  color: OtColors.accentDark),
              title: const Text('This Evening'),
              onTap: () => pick(
                  (bucket: StartBucket.anytime, date: today, isEvening: true)),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_rounded,
                  color: OtColors.upcomingRed),
              title: const Text('Tomorrow'),
              onTap: () => pick((
                bucket: StartBucket.anytime,
                date: today.add(const Duration(days: 1)),
                isEvening: false
              )),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded,
                  color: OtColors.anytimeTeal),
              title: const Text('Pick a date…'),
              onTap: () async {
                final navigator = Navigator.of(context);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: today,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  navigator.pop((
                    bucket: StartBucket.anytime,
                    date: picked,
                    isEvening: false
                  ));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_rounded,
                  color: OtColors.somedaySand),
              title: const Text('Someday'),
              onTap: () => pick(
                  (bucket: StartBucket.someday, date: null, isEvening: false)),
            ),
            ListTile(
              leading: const Icon(Icons.clear_rounded),
              title: const Text('Clear'),
              onTap: () => pick(
                  (bucket: StartBucket.anytime, date: null, isEvening: false)),
            ),
          ],
        ),
      );
    },
  );
}
