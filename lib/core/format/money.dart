/// The one way SkillNova shows money: "Rs 1,500".
///
/// Accepts the loose values stored in Firestore ("1500", "1,500",
/// "Rs. 1500", 1500). Text that isn't a plain amount (e.g. "Negotiable") is
/// returned unchanged; empty values return [empty].
String formatRupees(Object? raw, {String empty = ''}) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return empty;
  final digits = text
      .replaceAll(RegExp(r'rs\.?', caseSensitive: false), '')
      .trim();
  if (RegExp(r'[a-zA-Z]').hasMatch(digits)) return text;
  final number = double.tryParse(digits.replaceAll(RegExp(r'[^0-9.]'), ''));
  if (number == null) return text;
  final whole = number.round().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  return 'Rs $grouped';
}

/// Hourly rate: "Rs 1,500/hr".
String formatHourlyRate(Object? raw) {
  final amount = formatRupees(raw);
  if (amount.isEmpty || !amount.startsWith('Rs ')) return amount;
  return '$amount/hr';
}
