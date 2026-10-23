/// Amounts are always integers in the smallest currency unit (cents) to
/// avoid floating point rounding on prices and totals.
typedef Cents = int;

String formatCents(Cents cents, {String symbol = '€', String decimal = ','}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final units = abs ~/ 100;
  final rest = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$units$decimal$rest $symbol';
}
