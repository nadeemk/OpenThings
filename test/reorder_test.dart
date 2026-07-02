import 'package:flutter_test/flutter_test.dart';
import 'package:openthings/domain/reorder.dart';

void main() {
  // Display order indexes: a=10, b=20, c=30, d=40.
  const idx = [10.0, 20.0, 30.0, 40.0];

  test('move down lands between destination neighbors', () {
    // Move a (0) to after b — post-removal insertion position 1.
    expect(reorderedIndex(idx, 0, 1), 25.0); // between 20 and 30
  });

  test('move up lands between destination neighbors', () {
    // Move d (3) before b — insertion position 1.
    expect(reorderedIndex(idx, 3, 1), 15.0); // between 10 and 20
  });

  test('move to top goes before first', () {
    expect(reorderedIndex(idx, 2, 0), lessThan(10.0));
  });

  test('move to bottom goes after last', () {
    expect(reorderedIndex(idx, 0, 3), greaterThan(40.0));
  });

  test('single item keeps its index', () {
    expect(reorderedIndex(const [10.0], 0, 0), 10.0);
  });
}
