extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

extension IterSum on Iterable<num> {
  num get sum => this.isEmpty ? 0 : this.fold<num>(0, (a, b) => a + b);
}