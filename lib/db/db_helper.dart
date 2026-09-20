import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class DbHelper {
  DbHelper._();
  static final DbHelper instance = DbHelper._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'bahi.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE settings(
            id INTEGER PRIMARY KEY, biz_name TEXT, owner TEXT, phone TEXT,
            address TEXT, state TEXT, gstin TEXT, gst_reg INTEGER,
            def_type TEXT, incl INTEGER, prefix_g TEXT, next_g INTEGER,
            prefix_n TEXT, next_n INTEGER, upi TEXT, bank TEXT, terms TEXT,
            sig_key TEXT, pin TEXT, theme TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE shops(
            id TEXT PRIMARY KEY, name TEXT, phone TEXT, address TEXT,
            route TEXT, gstin TEXT, state TEXT, opening REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE products(
            id TEXT PRIMARY KEY, name TEXT, unit TEXT, hsn TEXT,
            price REAL, cost REAL, gst REAL, stock REAL, low REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE invoices(
            id TEXT PRIMARY KEY, no TEXT, date TEXT, ts INTEGER, type TEXT,
            shop_id TEXT, shop_name TEXT, party_json TEXT, incl INTEGER,
            gross REAL, disc REAL, taxable REAL, cgst REAL, sgst REAL,
            igst REAL, round_off REAL, total REAL, intra INTEGER,
            notes TEXT, status TEXT, cancelled INTEGER,
            auth_json TEXT, recv_json TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE invoice_items(
            rowid INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id TEXT,
            pid TEXT, name TEXT, hsn TEXT, unit TEXT, qty REAL, rate REAL,
            gst REAL, amt REAL, taxable REAL, cgst REAL, sgst REAL, igst REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE payments(
            id TEXT PRIMARY KEY, date TEXT, ts INTEGER, shop_id TEXT,
            invoice_id TEXT, amount REAL, mode TEXT, note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE moves(
            id TEXT PRIMARY KEY, pid TEXT, date TEXT, ts INTEGER,
            qty REAL, type TEXT, note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sigs(key TEXT PRIMARY KEY, data TEXT)
        ''');
      },
    );
  }

  // ---------- settings ----------
  Future<AppSettings> loadSettings() async {
    final d = await db;
    final rows = await d.query('settings', where: 'id = 1');
    if (rows.isEmpty) {
      final s = AppSettings();
      await d.insert('settings', {'id': 1, ...s.toMap()});
      return s;
    }
    return AppSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(AppSettings s) async {
    final d = await db;
    await d.insert('settings', {'id': 1, ...s.toMap()},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- shops ----------
  Future<List<Shop>> loadShops() async {
    final d = await db;
    final rows = await d.query('shops');
    return rows.map(Shop.fromMap).toList();
  }

  Future<void> upsertShop(Shop s) async {
    final d = await db;
    await d.insert('shops', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteShop(String id) async {
    final d = await db;
    await d.delete('shops', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- products ----------
  Future<List<Product>> loadProducts() async {
    final d = await db;
    final rows = await d.query('products');
    return rows.map(Product.fromMap).toList();
  }

  Future<void> upsertProduct(Product p) async {
    final d = await db;
    await d.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProduct(String id) async {
    final d = await db;
    await d.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- invoices ----------
  Future<List<Invoice>> loadInvoices() async {
    final d = await db;
    final invRows = await d.query('invoices');
    final itemRows = await d.query('invoice_items');
    final byInv = <String, List<InvoiceItem>>{};
    for (final r in itemRows) {
      final invId = r['invoice_id'] as String;
      (byInv[invId] ??= []).add(InvoiceItem(
        pid: r['pid'] as String? ?? '',
        name: r['name'] as String? ?? '',
        hsn: r['hsn'] as String? ?? '',
        unit: r['unit'] as String? ?? '',
        qty: num_(r['qty']),
        rate: num_(r['rate']),
        gst: num_(r['gst']),
        amt: num_(r['amt']),
        taxable: num_(r['taxable']),
        cgst: num_(r['cgst']),
        sgst: num_(r['sgst']),
        igst: num_(r['igst']),
      ));
    }
    return invRows.map((r) => Invoice.fromRow(r, byInv[r['id']] ?? [])).toList();
  }

  Future<void> insertInvoice(Invoice inv) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.insert('invoices', inv.toRowMap());
      for (final it in inv.items) {
        await txn.insert('invoice_items', {
          'invoice_id': inv.id,
          'pid': it.pid,
          'name': it.name,
          'hsn': it.hsn,
          'unit': it.unit,
          'qty': it.qty,
          'rate': it.rate,
          'gst': it.gst,
          'amt': it.amt,
          'taxable': it.taxable,
          'cgst': it.cgst,
          'sgst': it.sgst,
          'igst': it.igst,
        });
      }
    });
  }

  Future<void> updateInvoice(Invoice inv) async {
    final d = await db;
    await d.update('invoices', inv.toRowMap(), where: 'id = ?', whereArgs: [inv.id]);
  }

  // ---------- payments ----------
  Future<List<Payment>> loadPayments() async {
    final d = await db;
    final rows = await d.query('payments');
    return rows.map(Payment.fromMap).toList();
  }

  Future<void> insertPayment(Payment p) async {
    final d = await db;
    await d.insert('payments', p.toMap());
  }

  // ---------- stock moves ----------
  Future<List<StockMove>> loadMoves() async {
    final d = await db;
    final rows = await d.query('moves');
    return rows.map(StockMove.fromMap).toList();
  }

  Future<void> insertMove(StockMove m) async {
    final d = await db;
    await d.insert('moves', m.toMap());
  }

  // ---------- signatures ----------
  Future<Map<String, String>> loadSigs() async {
    final d = await db;
    final rows = await d.query('sigs');
    return {for (final r in rows) r['key'] as String: r['data'] as String};
  }

  Future<void> saveSig(String key, String data) async {
    final d = await db;
    await d.insert('sigs', {'key': key, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- wipe / restore ----------
  Future<void> eraseAll() async {
    final d = await db;
    await d.transaction((txn) async {
      for (final t in [
        'shops', 'products', 'invoices', 'invoice_items', 'payments', 'moves', 'sigs'
      ]) {
        await txn.delete(t);
      }
      await txn.delete('settings');
      await txn.insert('settings', {'id': 1, ...AppSettings().toMap()});
    });
  }
}