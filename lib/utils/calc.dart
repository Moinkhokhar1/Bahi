import '../../models/models.dart';
import 'format.dart';
import '../models/models.dart';

/// A single draft line item while building a bill (mutable, string-backed
/// inputs mirror the original web form fields).
class DraftItem {
  String pid;
  String name;
  String hsn;
  String unit;
  String qty;
  String rate;
  double gst;

  DraftItem({
    this.pid = '',
    this.name = '',
    this.hsn = '',
    this.unit = '',
    this.qty = '1',
    this.rate = '0',
    this.gst = 0,
  });
}

/// A computed line, ready to become an InvoiceItem.
class CalcLine {
  final DraftItem src;
  final double amt;
  double taxable = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;
  CalcLine(this.src, this.amt);
}

class CalcResult {
  final List<CalcLine> lines;
  final double gross;
  final double disc;
  final double taxable;
  final double cgst;
  final double sgst;
  final double igst;
  final double raw;
  final double round;
  final double total;
  final bool intra;

  CalcResult({
    required this.lines,
    required this.gross,
    required this.disc,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.raw,
    required this.round,
    required this.total,
    required this.intra,
  });
}

/// Mirrors the JS `calc(d, st, shop)` function.
CalcResult calcBill({
  required String type,
  required List<DraftItem> items,
  required String discount,
  required bool inclGst,
  required String sellerState,
  String? shopState,
}) {
  final gst = type == 'gst';
  final incl = inclGst && gst;

  final lines = items.map((it) => CalcLine(it, num_(it.qty) * num_(it.rate))).toList();
  final gross = sumBy(lines, (l) => l.amt);
  final disc = num_(discount).clamp(0, gross > 0 ? gross : double.infinity).toDouble();

  final intra = shopState == null || shopState.isEmpty || sellerState.isEmpty || shopState == sellerState;

  double taxable = 0, cgst = 0, sgst = 0, igst = 0;

  for (final l in lines) {
    final net = l.amt - (gross != 0 ? l.amt / gross * disc : 0);
    final rate = gst ? l.src.gst : 0.0;
    double base = net;
    double tax = 0;
    if (gst) {
      if (incl) {
        base = net * 100 / (100 + rate);
        tax = net - base;
      } else {
        tax = base * rate / 100;
      }
    }
    l.taxable = base;
    if (intra) {
      l.cgst = tax / 2;
      l.sgst = tax / 2;
      l.igst = 0;
    } else {
      l.igst = tax;
      l.cgst = 0;
      l.sgst = 0;
    }
    taxable += l.taxable;
    cgst += l.cgst;
    sgst += l.sgst;
    igst += l.igst;
  }

  final raw = taxable + cgst + sgst + igst;
  final total = raw.round().toDouble();

  return CalcResult(
    lines: lines,
    gross: gross,
    disc: disc,
    taxable: taxable,
    cgst: cgst,
    sgst: sgst,
    igst: igst,
    raw: raw,
    round: total - raw,
    total: total,
    intra: intra,
  );
}

/// Mirrors the JS FNV-1a based sigId() hash used as a "sign ID" stamp.
String sigId(Invoice inv) {
  int h = 0x811c9dc5;
  final s = '${inv.no}|${inv.total}|${inv.date}|${inv.shopName}|${inv.ts}';
  for (final code in s.codeUnits) {
    h ^= code;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).toUpperCase().padLeft(8, '0');
}