/// LIFO stack of tab indices for in-app browser/system back navigation.
class TabHistoryStack {
  final List<int> _entries = <int>[];

  bool get isEmpty => _entries.isEmpty;

  int get length => _entries.length;

  void push(int index) => _entries.add(index);

  int? pop() {
    if (_entries.isEmpty) {
      return null;
    }
    return _entries.removeLast();
  }

  void clear() => _entries.clear();
}
