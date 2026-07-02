import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/app/built_in_lists.dart';

void main() {
  test('built-in lists are in Things order', () {
    expect(BuiltInList.values.map((l) => l.title).toList(), [
      'Inbox',
      'Today',
      'Upcoming',
      'Anytime',
      'Someday',
      'Logbook',
      'Trash',
    ]);
  });
}
