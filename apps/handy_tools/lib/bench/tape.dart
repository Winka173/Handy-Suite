import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';

class TapeEntry {
  /// What was typed or chosen, shown in grey.
  final String input;

  /// The answer as displayed and as copied.
  final String answer;

  /// Engine value when the answer is a plain number; it joins the total.
  final String? number;

  /// Where to reopen it: a tool id and its field values.
  final String toolId;
  final Map<String, String> values;

  /// Typed into the free entry (reopens as text) rather than a tool's form.
  final bool free;
  const TapeEntry({
    required this.input,
    this.free = false,
    required this.answer,
    required this.toolId,
    required this.values,
    this.number,
  });
}

/// The adding-machine tape of this session. Memory only: answers can hold
/// private amounts or text, so nothing here touches the disk.
class TapeController extends ChangeNotifier {
  static const limit = 50;
  final List<TapeEntry> entries = [];

  void add(TapeEntry entry) {
    if (entries.isNotEmpty &&
        entries.first.input == entry.input &&
        entries.first.answer == entry.answer) {
      return;
    }
    entries.insert(0, entry);
    if (entries.length > limit) entries.removeLast();
    notifyListeners();
  }

  void remove(int index) {
    entries.removeAt(index);
    notifyListeners();
  }

  void clear() {
    entries.clear();
    notifyListeners();
  }

  /// Exact decimal sum of the numeric answers, or null when there are none.
  String? get total {
    final numbers = entries.map((e) => e.number).whereType<String>().toList();
    if (numbers.isEmpty) return null;
    return calculate(numbers.map((n) => '($n)').join('+'));
  }

  int get counted => entries.where((e) => e.number != null).length;
}

bool isPlainNumber(String s) => RegExp(r'^-?\d+(\.\d+)?$').hasMatch(s);
