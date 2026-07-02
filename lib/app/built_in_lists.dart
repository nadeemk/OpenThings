import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// The built-in smart lists shown in the sidebar, in Things' order.
enum BuiltInList {
  inbox('Inbox', '/inbox', Icons.inbox_rounded, OtColors.inboxBlue),
  today('Today', '/today', Icons.star_rounded, OtColors.todayYellow),
  upcoming(
      'Upcoming', '/upcoming', Icons.calendar_month_rounded, OtColors.upcomingRed),
  anytime('Anytime', '/anytime', Icons.layers_rounded, OtColors.anytimeTeal),
  someday('Someday', '/someday', Icons.archive_rounded, OtColors.somedaySand),
  logbook('Logbook', '/logbook', Icons.book_rounded, OtColors.logbookGreen),
  trash('Trash', '/trash', Icons.delete_rounded, OtColors.trashGray);

  const BuiltInList(this.title, this.route, this.icon, this.color);

  final String title;
  final String route;
  final IconData icon;
  final Color color;
}
