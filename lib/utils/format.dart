import 'dart:math';
import 'package:intl/intl.dart';

final _inMoney = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inMoneyWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inNum2 = NumberFormat('#,##,##0.00', 'en_IN');

double round2(double n) => (n * 100).round() / 100;

String fq(double n) {
  final r = (n * 1000).round() / 1000;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return r.toString();
}

String fnum(double n) => _inNum2.format(n);

String money(double n) {
  n = round2(n);
  final isInt = n == n.roundToDouble();
  final s = isInt ? _inMoneyWhole.format(n.abs()) : _inMoney.format(n.abs());
  return (n < 0 ? '\u2212' : '') + s;
}

const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String isoOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String today() => isoOf(DateTime.now());

String daysAgo(int n) => isoOf(DateTime.now().subtract(Duration(days: n)));

String fdate(String iso) {
  if (iso.isEmpty) return '';
  final p = iso.split('-');
  return '${int.parse(p[2])} ${MON[int.parse(p[1]) - 1]} ${p[0]}';
}

String fshort(String iso) {
  final p = iso.split('-');
  return '${int.parse(p[2])} ${MON[int.parse(p[1]) - 1]}';
}

String fdt(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final t = TimeOfDayFmt(d.hour, d.minute).format();
  return '${fdate(isoOf(d))}, $t';
}

class TimeOfDayFmt {
  final int hour;
  final int minute;
  TimeOfDayFmt(this.hour, this.minute);
  String format() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final ap = hour >= 12 ? 'pm' : 'am';
    return '$h:${minute.toString().padLeft(2, '0')} $ap';
  }
}

final RegExp GSTIN_RE =
RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

const List<int> GSTR = [0, 3, 5, 12, 18, 28, 40];

const List<String> UNITS = [
  'pcs', 'kg', 'g', 'ltr', 'box', 'pack', 'dozen', 'bag', 'carton', 'set'
];

const List<List<String>> STATES = [
  ["01", "Jammu & Kashmir"], ["02", "Himachal Pradesh"], ["03", "Punjab"],
  ["04", "Chandigarh"], ["05", "Uttarakhand"], ["06", "Haryana"],
  ["07", "Delhi"], ["08", "Rajasthan"], ["09", "Uttar Pradesh"],
  ["10", "Bihar"], ["11", "Sikkim"], ["12", "Arunachal Pradesh"],
  ["13", "Nagaland"], ["14", "Manipur"], ["15", "Mizoram"],
  ["16", "Tripura"], ["17", "Meghalaya"], ["18", "Assam"],
  ["19", "West Bengal"], ["20", "Jharkhand"], ["21", "Odisha"],
  ["22", "Chhattisgarh"], ["23", "Madhya Pradesh"], ["24", "Gujarat"],
  ["26", "Dadra & Nagar Haveli and Daman & Diu"], ["27", "Maharashtra"],
  ["29", "Karnataka"], ["30", "Goa"], ["31", "Lakshadweep"],
  ["32", "Kerala"], ["33", "Tamil Nadu"], ["34", "Puducherry"],
  ["35", "Andaman & Nicobar"], ["36", "Telangana"], ["37", "Andhra Pradesh"],
  ["38", "Ladakh"],
];

String stateName(String code) {
  for (final s in STATES) {
    if (s[0] == code) return s[1];
  }
  return '';
}

String words(double nIn) {
  int n = nIn.round();
  if (n == 0) return 'Zero';
  const a = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen',
    'Nineteen'];
  const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String two(int x) => x < 20 ? a[x] : b[x ~/ 10] + (x % 10 != 0 ? ' ${a[x % 10]}' : '');
  String three(int x) =>
      (x > 99 ? '${a[x ~/ 100]} Hundred${x % 100 != 0 ? ' ' : ''}' : '') +
          (x % 100 != 0 ? two(x % 100) : '');
  String o = '';
  int cr = n ~/ 10000000;
  n %= 10000000;
  int lk = n ~/ 100000;
  n %= 100000;
  int th = n ~/ 1000;
  n %= 1000;
  if (cr != 0) o += '${three(cr)} Crore ';
  if (lk != 0) o += '${two(lk)} Lakh ';
  if (th != 0) o += '${two(th)} Thousand ';
  if (n != 0) o += three(n);
  return o.trim();
}

String uid() {
  final r = Random();
  final part1 = r.nextInt(1 << 32).toRadixString(36);
  final part2 = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  return (part1 + part2).substring(0, min(12, (part1 + part2).length));
}

double sumBy<T>(Iterable<T> items, double Function(T) f) {
  double t = 0;
  for (final i in items) {
    t += f(i);
  }
  return t;
}