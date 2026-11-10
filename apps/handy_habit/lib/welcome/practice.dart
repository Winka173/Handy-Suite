/// Disposable rehearsal state. Deliberately has no app, engine or storage port.
class HabitPractice {
  int step = 0;
  int get water => step == 1 ? 1 : 0;
  int get goal => step >= 3 ? 8 : 3;
  bool get running => step == 4;
  bool get finished => step >= 5;
  bool get done => step == 6;
  void advance() {
    if (!done) step++;
  }

  void back() {
    if (step > 0) step--;
  }
}
