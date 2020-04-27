extension StringExtension on String {
  /// A copy of this [String] where the first letter is upper cased.
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

extension IterSum on Iterable<num> {
  num get sum => this.isEmpty ? 0 : this.fold<num>(0, (a, b) => a + b);
}