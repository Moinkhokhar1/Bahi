import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../db/db_helper.dart';
import '../../models/models.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart' hide round2;

class AppState extends ChangeNotifier {
  final DbHelper _dbi = DbHelper.instance;

  AppSettings settings = AppSettings();
  List<Shop> shops = [];
  List<Product> products = [];
  List<Invoice> invoices = [];
  List<Payment> payments = [];
  List<StockMove> moves = [];
  Map<String, String> sigs = {};

  bool loaded = false;

  Future<void> init() async {
    settings = await _dbi.loadSettings();
    shops = await _dbi.loadShops();
    products = await _dbi.loadProducts();
    invoices = await _dbi.loadInvoices();
    payments = await _dbi.loadPayments();
    moves = await _dbi.loadMoves();
    sigs = await _dbi.loadSigs();
    loaded = true;
    notifyListeners();
  }

  // ---------- lookups ----------
  Shop? shopById(String id) {
    for (final s in shops) {
      if (s.id == id) return s;
    }
    return null;
  }

  Product? prodById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Invoice? invById(String id) {
    for (final i in invoices) {
      if (i.id == id) return i;
    }
    return null;
  }

  String sigOf(String key) => key.isEmpty ? '' : (sigs[key] ?? '');

  // ---------- accounting ----------
  double shopBal(Shop s) {
    final invTotal = sumBy(
      invoices.where((i) => i.shopId == s.id && !i.cancelled),
          (i) => i.total,
    );
    final paid = sumBy(payments.where((p) => p.shopId == s.id), (p) => p.amount);
    return round2(s.opening + invTotal - paid);
  }

  /// invoiceId -> amount paid against it (applying unallocated shop
  /// payments to the oldest pending invoices first, like the JS pool logic).
  Map<String, double> paidMap() {
    final m = <String, double>{for (final i in invoices) i.id: 0};
    final pool = <String, double>{};
    for (final p in payments) {
      if (p.invoiceId.isNotEmpty && m.containsKey(p.invoiceId)) {
        m[p.invoiceId] = (m[p.invoiceId] ?? 0) + p.amount;
      } else {
        final k = p.shopId;
        pool[k] = (pool[k] ?? 0) + p.amount;
      }
    }
    final sorted = invoices.where((i) => !i.cancelled).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    for (final i in sorted) {
      final k = i.shopId;
      final rem = i.total - (m[i.id] ?? 0);
      if (rem > 0.005 && (pool[k] ?? 0) > 0) {
        final t = min(rem, pool[k]!);
        m[i.id] = (m[i.id] ?? 0) + t;
        pool[k] = pool[k]! - t;
      }
    }
    return m;
  }

  // ---------- invoices ----------
  /// Builds and persists an invoice from a draft. Returns the created
  /// invoice. Also deducts stock and books the "paid now" amount.
  Future<Invoice> commitInvoice({
    required String type,
    required String shopId,
    required bool walk,
    required List<DraftItem> items,
    required String discount,
    required bool incl,
    required String paidNow,
    required String mode,
    required String notes,
    required bool attachSig,
  }) async {
    final shop = shopId.isNotEmpty ? shopById(shopId) : null;
    final gst = type == 'gst';
    final c = calcBill(
      type: type,
      items: items,
      discount: discount,
      inclGst: incl,
      sellerState: settings.state,
      shopState: shop?.state,
    );
    final ts = DateTime.now().millisecondsSinceEpoch;
    final date = today();
    final no = gst
        ? '${settings.prefixG}-${(settings.nextG).toString().padLeft(4, '0')}'
        : '${settings.prefixN}-${(settings.nextN).toString().padLeft(4, '0')}';
    if (gst) {
      settings.nextG += 1;
    } else {
      settings.nextN += 1;
    }

    final invItems = c.lines
        .map((l) => InvoiceItem(
      pid: l.src.pid,
      name: l.src.name,
      hsn: l.src.hsn,
      unit: l.src.unit,
      qty: num_(l.src.qty),
      rate: num_(l.src.rate),
      gst: gst ? l.src.gst : 0,
      amt: round2(l.amt),
      taxable: round2(l.taxable),
      cgst: round2(l.cgst),
      sgst: round2(l.sgst),
      igst: round2(l.igst),
    ))
        .toList();

    final inv = Invoice(
      id: uid(),
      no: no,
      date: date,
      ts: ts,
      type: type,
      shopId: shopId,
      shopName: shop?.name ?? 'Walk-in customer',
      party: shop != null
          ? Party(
          name: shop.name,
          address: shop.address,
          gstin: shop.gstin,
          state: shop.state,
          phone: shop.phone)
          : Party(name: 'Walk-in customer'),
      incl: incl && gst,
      items: invItems,
      gross: round2(c.gross),
      disc: round2(c.disc),
      taxable: round2(c.taxable),
      cgst: round2(c.cgst),
      sgst: round2(c.sgst),
      igst: round2(c.igst),
      round: round2(c.round),
      total: c.total,
      intra: c.intra,
      notes: notes,
      status: 'pending',
      cancelled: false,
    );

    if (attachSig && settings.sigKey.isNotEmpty) {
      final auth = SignBlock(
        name: settings.owner.isNotEmpty ? settings.owner : settings.bizName,
        sig: settings.sigKey,
        ts: ts,
      );
      auth.id = sigId(inv..auth = auth);
      inv.auth = auth;
    }

    // stock deduction + movement log
    for (final it in inv.items) {
      if (it.pid.isNotEmpty) {
        final p = prodById(it.pid);
        if (p != null) {
          p.stock = round2(p.stock - it.qty);
          await _dbi.upsertProduct(p);
          final mv = StockMove(
              id: uid(), pid: p.id, date: date, ts: ts, qty: -it.qty, type: 'out', note: 'Bill $no');
          moves.add(mv);
          await _dbi.insertMove(mv);
        }
      }
    }

    invoices.add(inv);
    await _dbi.insertInvoice(inv);
    await _dbi.saveSettings(settings);

    final paidVal = shopId.isEmpty ? c.total : min(c.total, max(0, num_(paidNow)));
    if (paidVal > 0) {
      final pay = Payment(
        id: uid(),
        date: date,
        ts: ts,
        shopId: shopId,
        invoiceId: inv.id,
        amount: round2(paidVal),
        mode: mode,
        note: 'With bill $no',
      );
      payments.add(pay);
      await _dbi.insertPayment(pay);
    }

    notifyListeners();
    return inv;
  }

  Future<void> cancelInvoice(String id) async {
    final inv = invById(id);
    if (inv == null) return;
    inv.cancelled = true;
    for (final it in inv.items) {
      if (it.pid.isNotEmpty) {
        final p = prodById(it.pid);
        if (p != null) {
          p.stock = round2(p.stock + it.qty);
          await _dbi.upsertProduct(p);
          final mv = StockMove(
              id: uid(),
              pid: p.id,
              date: today(),
              ts: DateTime.now().millisecondsSinceEpoch,
              qty: it.qty,
              type: 'in',
              note: 'Cancelled ${inv.no}');
          moves.add(mv);
          await _dbi.insertMove(mv);
        }
      }
    }
    await _dbi.updateInvoice(inv);
    notifyListeners();
  }

  Future<void> deliverInvoice(String id, {required String recvName, String? sigData}) async {
    final inv = invById(id);
    if (inv == null) return;
    inv.status = 'delivered';
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (sigData != null && sigData.isNotEmpty) {
      final k = 'r${uid()}';
      sigs[k] = sigData;
      await _dbi.saveSig(k, sigData);
      inv.recv = SignBlock(name: recvName, sig: k, ts: ts);
    } else {
      inv.recv = SignBlock(name: recvName, sig: '', ts: ts);
    }
    await _dbi.updateInvoice(inv);
    notifyListeners();
  }

  // ---------- shops ----------
  Future<void> saveShop(Shop s) async {
    final existing = shopById(s.id);
    if (existing == null) shops.add(s);
    await _dbi.upsertShop(s);
    notifyListeners();
  }

  Future<void> deleteShop(String id) async {
    shops.removeWhere((s) => s.id == id);
    payments.removeWhere((p) => p.shopId == id);
    await _dbi.deleteShop(id);
    notifyListeners();
  }

  bool shopHasInvoices(String id) => invoices.any((i) => i.shopId == id);

  // ---------- products ----------
  Future<void> saveProduct(Product p, {double? openingStock}) async {
    final existing = prodById(p.id);
    final isNew = existing == null;
    if (isNew) products.add(p);
    await _dbi.upsertProduct(p);
    if (isNew && openingStock != null && openingStock != 0) {
      final mv = StockMove(
          id: uid(),
          pid: p.id,
          date: today(),
          ts: DateTime.now().millisecondsSinceEpoch,
          qty: openingStock,
          type: 'in',
          note: 'Opening stock');
      moves.add(mv);
      await _dbi.insertMove(mv);
    }
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    products.removeWhere((p) => p.id == id);
    await _dbi.deleteProduct(id);
    notifyListeners();
  }

  Future<void> stockAdjust({
    required String pid,
    required double qty,
    required bool isIn,
    double? cost,
    String note = '',
  }) async {
    final p = prodById(pid);
    if (p == null) return;
    final sign = isIn ? 1 : -1;
    p.stock = round2(p.stock + sign * qty);
    if (isIn && cost != null && cost > 0) p.cost = round2(cost);
    await _dbi.upsertProduct(p);
    final mv = StockMove(
      id: uid(),
      pid: p.id,
      date: today(),
      ts: DateTime.now().millisecondsSinceEpoch,
      qty: sign * qty,
      type: isIn ? 'in' : 'adj',
      note: note.isNotEmpty ? note : (isIn ? 'Stock in' : 'Stock reduced'),
    );
    moves.add(mv);
    await _dbi.insertMove(mv);
    notifyListeners();
  }

  // ---------- payments ----------
  Future<void> addPayment({
    required String shopId,
    required double amount,
    required String mode,
    String note = '',
    String invoiceId = '',
  }) async {
    final pay = Payment(
      id: uid(),
      date: today(),
      ts: DateTime.now().millisecondsSinceEpoch,
      shopId: shopId,
      invoiceId: invoiceId,
      amount: round2(amount),
      mode: mode,
      note: note,
    );
    payments.add(pay);
    await _dbi.insertPayment(pay);
    notifyListeners();
  }

  // ---------- settings & signature ----------
  Future<void> saveSettings(AppSettings s) async {
    settings = s;
    await _dbi.saveSettings(s);
    notifyListeners();
  }

  Future<void> saveSignature(String data) async {
    final k = 'a${uid()}';
    sigs[k] = data;
    await _dbi.saveSig(k, data);
    settings.sigKey = k;
    await _dbi.saveSettings(settings);
    notifyListeners();
  }

  Future<void> removeSignature() async {
    settings.sigKey = '';
    await _dbi.saveSettings(settings);
    notifyListeners();
  }

  // ---------- backup / restore ----------
  String backupJson() {
    final map = {
      'v': 1,
      'settings': {
        'bizName': settings.bizName,
        'owner': settings.owner,
        'phone': settings.phone,
        'address': settings.address,
        'state': settings.state,
        'gstin': settings.gstin,
        'gstReg': settings.gstReg,
        'defType': settings.defType,
        'incl': settings.incl,
        'prefixG': settings.prefixG,
        'nextG': settings.nextG,
        'prefixN': settings.prefixN,
        'nextN': settings.nextN,
        'upi': settings.upi,
        'bank': settings.bank,
        'terms': settings.terms,
        'sigKey': settings.sigKey,
        'pin': settings.pin,
        'theme': settings.theme,
      },
      'shops': shops.map((s) => s.toJson()).toList(),
      'products': products.map((p) => p.toJson()).toList(),
      'invoices': invoices.map((i) => i.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'moves': moves.map((m) => m.toJson()).toList(),
      'sigs': sigs,
    };
    return jsonEncode(map);
  }

  /// Returns true on success.
  Future<bool> restoreFromJson(String text) async {
    try {
      final d = jsonDecode(text) as Map<String, dynamic>;
      if (d['shops'] is! List || d['invoices'] is! List || d['settings'] == null) {
        return false;
      }
      await _dbi.eraseAll();

      settings = AppSettings.fromJson(d['settings']);
      await _dbi.saveSettings(settings);

      shops = (d['shops'] as List).map((e) => Shop.fromJson(e)).toList();
      for (final s in shops) {
        await _dbi.upsertShop(s);
      }

      products = ((d['products'] as List?) ?? []).map((e) => Product.fromJson(e)).toList();
      for (final p in products) {
        await _dbi.upsertProduct(p);
      }

      invoices = (d['invoices'] as List).map((e) => Invoice.fromJson(e)).toList();
      for (final i in invoices) {
        await _dbi.insertInvoice(i);
      }

      payments = ((d['payments'] as List?) ?? []).map((e) => Payment.fromJson(e)).toList();
      for (final p in payments) {
        await _dbi.insertPayment(p);
      }

      moves = ((d['moves'] as List?) ?? []).map((e) => StockMove.fromJson(e)).toList();
      for (final m in moves) {
        await _dbi.insertMove(m);
      }

      sigs = Map<String, String>.from((d['sigs'] as Map?) ?? {});
      for (final e in sigs.entries) {
        await _dbi.saveSig(e.key, e.value);
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> eraseAll() async {
    await _dbi.eraseAll();
    settings = AppSettings();
    shops = [];
    products = [];
    invoices = [];
    payments = [];
    moves = [];
    sigs = {};
    notifyListeners();
  }

  Future<void> loadSample() async {
    await eraseAll();
    settings = AppSettings(
      bizName: 'Demo Traders',
      owner: 'Ravi Mehta',
      phone: '9800000001',
      address: '12 Wholesale Market, Sample Nagar',
      state: '27',
      gstin: '27AAPFU0939F1ZV',
      gstReg: true,
      defType: 'gst',
      upi: 'demotraders@upi',
      bank: 'Sample Bank, A/c 0000 0000 0000, IFSC SAMP0000001',
    );
    await _dbi.saveSettings(settings);

    final prodSeed = [
      ['Glucose Biscuits (carton)', 'carton', '19053100', 900.0, 760.0, 18.0, 60.0, 10.0],
      ['Iodised Salt 1 kg', 'pack', '25010010', 22.0, 17.0, 0.0, 300.0, 50.0],
      ['Basmati Rice 25 kg', 'bag', '10063020', 1650.0, 1480.0, 5.0, 40.0, 8.0],
      ['Sunflower Oil 1 L', 'pack', '15121910', 145.0, 128.0, 5.0, 120.0, 24.0],
      ['Tea Powder 500 g', 'pack', '09024010', 240.0, 205.0, 5.0, 90.0, 15.0],
      ['Toor Dal 1 kg', 'pack', '07136000', 135.0, 118.0, 5.0, 110.0, 20.0],
      ['Sugar 1 kg', 'pack', '17019990', 46.0, 41.0, 5.0, 200.0, 40.0],
      ['Detergent Powder 1 kg', 'pack', '34022090', 110.0, 92.0, 18.0, 80.0, 15.0],
      ['Bathing Soap (pack of 4)', 'pack', '34011190', 140.0, 115.0, 18.0, 70.0, 12.0],
      ['Exercise Notebook', 'dozen', '48202000', 300.0, 250.0, 0.0, 50.0, 10.0],
    ];
    products = [];
    for (var i = 0; i < prodSeed.length; i++) {
      final p = prodSeed[i];
      final prod = Product(
        id: 'p$i',
        name: p[0] as String,
        unit: p[1] as String,
        hsn: p[2] as String,
        price: p[3] as double,
        cost: p[4] as double,
        gst: p[5] as double,
        stock: p[6] as double,
        low: p[7] as double,
      );
      products.add(prod);
      await _dbi.upsertProduct(prod);
    }

    final shopSeed = [
      ['Sharma Kirana Store', '9800000011', 'Main Road, Sample Nagar', 'Monday route', '27ABCPS1234K1Z5', '27', 1200.0],
      ['New Laxmi General Store', '9800000012', 'Station Lane, Sample Nagar', 'Monday route', '', '27', 0.0],
      ['Fresh Mart Supermarket', '9800000013', 'Highway Circle, Sample City', 'Thursday route', '27AAACF5678M1ZC', '27', 3500.0],
      ['Anand Provision', '9800000014', 'Temple Street, Sample Nagar', 'Thursday route', '', '27', 0.0],
      ['Om Sai Traders', '9800000015', 'Industrial Estate, Other City', 'Other state', '29ABCDE1234F1Z5', '29', 0.0],
    ];
    shops = [];
    for (var i = 0; i < shopSeed.length; i++) {
      final s = shopSeed[i];
      final shop = Shop(
        id: 's$i',
        name: s[0] as String,
        phone: s[1] as String,
        address: s[2] as String,
        route: s[3] as String,
        gstin: s[4] as String,
        state: s[5] as String,
        opening: s[6] as double,
      );
      shops.add(shop);
      await _dbi.upsertShop(shop);
    }

    invoices = [];
    payments = [];
    moves = [];
    int seed = 7;
    double rnd() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    for (var d = 12; d >= 0; d--) {
      final n = 1 + (rnd() * 2).floor();
      for (var k = 0; k < n; k++) {
        final shop = shops[(rnd() * shops.length).floor()];
        final used = <String>{};
        final cnt = 2 + (rnd() * 3).floor();
        final items = <DraftItem>[];
        for (var j = 0; j < cnt; j++) {
          final p = products[(rnd() * products.length).floor()];
          if (used.contains(p.id)) continue;
          used.add(p.id);
          final q = p.unit == 'pack' ? 6 + (rnd() * 18).floor() : 1 + (rnd() * 4).floor();
          items.add(DraftItem(
              pid: p.id, name: p.name, hsn: p.hsn, unit: p.unit, qty: '$q', rate: '${p.price}', gst: p.gst));
        }
        final type = (shop.gstin.isNotEmpty || rnd() > 0.55) ? 'gst' : 'nongst';
        final dt = daysAgo(d);
        final ts = DateTime.parse(dt).add(Duration(hours: 9 + k * 4, minutes: 30)).millisecondsSinceEpoch;
        final discStr = rnd() > 0.7 ? '50' : '';
        final c = calcBill(
          type: type,
          items: items,
          discount: discStr,
          inclGst: false,
          sellerState: settings.state,
          shopState: shop.state,
        );
        final r = rnd();
        final paidStr = r > 0.55 ? '${c.total}' : (r > 0.3 ? '${(c.total / 2).round()}' : '');
        final mode = rnd() > 0.5 ? 'UPI' : 'Cash';

        final gst = type == 'gst';
        final no = gst
            ? '${settings.prefixG}-${(settings.nextG).toString().padLeft(4, '0')}'
            : '${settings.prefixN}-${(settings.nextN).toString().padLeft(4, '0')}';
        if (gst) {
          settings.nextG += 1;
        } else {
          settings.nextN += 1;
        }
        final invItems = c.lines
            .map((l) => InvoiceItem(
          pid: l.src.pid,
          name: l.src.name,
          hsn: l.src.hsn,
          unit: l.src.unit,
          qty: num_(l.src.qty),
          rate: num_(l.src.rate),
          gst: gst ? l.src.gst : 0,
          amt: round2(l.amt),
          taxable: round2(l.taxable),
          cgst: round2(l.cgst),
          sgst: round2(l.sgst),
          igst: round2(l.igst),
        ))
            .toList();
        final inv = Invoice(
          id: uid(),
          no: no,
          date: dt,
          ts: ts,
          type: type,
          shopId: shop.id,
          shopName: shop.name,
          party: Party(name: shop.name, address: shop.address, gstin: shop.gstin, state: shop.state, phone: shop.phone),
          incl: false,
          items: invItems,
          gross: round2(c.gross),
          disc: round2(c.disc),
          taxable: round2(c.taxable),
          cgst: round2(c.cgst),
          sgst: round2(c.sgst),
          igst: round2(c.igst),
          round: round2(c.round),
          total: c.total,
          intra: c.intra,
          status: (d > 0 || k == 0) ? 'delivered' : 'pending',
        );
        if (d > 0 || k == 0) {
          inv.recv = SignBlock(name: 'Store staff', sig: '', ts: ts + 3600000);
        }
        for (final it in invItems) {
          final p = prodById(it.pid);
          if (p != null) {
            p.stock = round2(p.stock - it.qty);
            await _dbi.upsertProduct(p);
          }
        }
        invoices.add(inv);
        await _dbi.insertInvoice(inv);
        if (paidStr.isNotEmpty) {
          final paidVal = num_(paidStr);
          if (paidVal > 0) {
            final pay = Payment(
              id: uid(),
              date: dt,
              ts: ts,
              shopId: shop.id,
              invoiceId: inv.id,
              amount: round2(paidVal),
              mode: mode,
              note: 'With bill $no',
            );
            payments.add(pay);
            await _dbi.insertPayment(pay);
          }
        }
      }
    }
    await _dbi.saveSettings(settings);
    notifyListeners();
  }
}