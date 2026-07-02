/// Computes the new fractional order index for a drag-reorder.
///
/// [orderIndexes] are the current indexes in display order. [newIndex]
/// is the post-removal insertion position (Flutter's `onReorderItem`
/// convention — already adjusted for the removed item). Returns the
/// midpoint between the destination neighbors.
double reorderedIndex(
    List<double> orderIndexes, int oldIndex, int newIndex) {
  assert(orderIndexes.isNotEmpty);
  final without = [...orderIndexes]..removeAt(oldIndex);
  if (without.isEmpty) return orderIndexes[oldIndex];
  if (newIndex <= 0) return without.first - 1024;
  if (newIndex >= without.length) return without.last + 1024;
  return (without[newIndex - 1] + without[newIndex]) / 2;
}
