import 'dart:math';

class IdGenerator {
  static final _random = Random();

  static String generateId({String prefix = ''}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(9000) + 1000;
    return prefix.isEmpty ? '$now$rand' : '$prefix-$now-$rand';
  }

  static String generateTransactionNumber() {
    final now = DateTime.now();
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = _random.nextInt(9000) + 1000;
    return 'TRX-$ymd-$rand';
  }

  static String generatePurchaseNumber() {
    final now = DateTime.now();
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = _random.nextInt(9000) + 1000;
    return 'PO-$ymd-$rand';
  }
}
