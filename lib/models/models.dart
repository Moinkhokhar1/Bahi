import 'dart:convert';

double num_(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '');
  return double.tryParse(s) ?? 0;
}

double round2(double n) => ((n * 100).round() / 100).toDouble();

class AppSettings {
  String bizName;
  String owner;
  String phone;
  String address;
  String state;
  String gstin;
  bool gstReg;
  String defType; // 'gst' | 'nongst'
  bool incl;
  String prefixG;
  int nextG;
  String prefixN;
  int nextN;
  String upi;
  String bank;
  String terms;
  String sigKey;
  String pin;
  String theme; // 'auto' | 'light' | 'dark'

  AppSettings({
    this.bizName = '',
    this.owner = '',
    this.phone = '',
    this.address = '',
    this.state = '',
    this.gstin = '',
    this.gstReg = true,
    this.defType = 'gst',
    this.incl = false,
    this.prefixG = 'INV',
    this.nextG = 1,
    this.prefixN = 'BS',
    this.nextN = 1,
    this.upi = '',
    this.bank = '',
    this.terms = 'Goods once sold will not be taken back.',
    this.sigKey = '',
    this.pin = '',
    this.theme = 'auto',
  });

  Map<String, dynamic> toMap() => {
    'biz_name': bizName,
    'owner': owner,
    'phone': phone,
    'address': address,
    'state': state,
    'gstin': gstin,
    'gst_reg': gstReg ? 1 : 0,
    'def_type': defType,
    'incl': incl ? 1 : 0,
    'prefix_g': prefixG,
    'next_g': nextG,
    'prefix_n': prefixN,
    'next_n': nextN,
    'upi': upi,
    'bank': bank,
    'terms': terms,
    'sig_key': sigKey,
    'pin': pin,
    'theme': theme,
  };

  static AppSettings fromMap(Map<String, dynamic> m) => AppSettings(
    bizName: m['biz_name'] ?? '',
    owner: m['owner'] ?? '',
    phone: m['phone'] ?? '',
    address: m['address'] ?? '',
    state: m['state'] ?? '',
    gstin: m['gstin'] ?? '',
    gstReg: (m['gst_reg'] ?? 1) == 1,
    defType: m['def_type'] ?? 'gst',
    incl: (m['incl'] ?? 0) == 1,
    prefixG: m['prefix_g'] ?? 'INV',
    nextG: m['next_g'] ?? 1,
    prefixN: m['prefix_n'] ?? 'BS',
    nextN: m['next_n'] ?? 1,
    upi: m['upi'] ?? '',
    bank: m['bank'] ?? '',
    terms: m['terms'] ?? '',
    sigKey: m['sig_key'] ?? '',
    pin: m['pin'] ?? '',
    theme: m['theme'] ?? 'auto',
  );

  Map<String, dynamic> toJson() => toMap();
  static AppSettings fromJson(Map<String, dynamic> j) => fromMap({
    'biz_name': j['bizName'],
    'owner': j['owner'],
    'phone': j['phone'],
    'address': j['address'],
    'state': j['state'],
    'gstin': j['gstin'],
    'gst_reg': (j['gstReg'] == true) ? 1 : 0,
    'def_type': j['defType'],
    'incl': (j['incl'] == true) ? 1 : 0,
    'prefix_g': j['prefixG'],
    'next_g': j['nextG'],
    'prefix_n': j['prefixN'],
    'next_n': j['nextN'],
    'upi': j['upi'],
    'bank': j['bank'],
    'terms': j['terms'],
    'sig_key': j['sigKey'],
    'pin': j['pin'],
    'theme': j['theme'],
  });
}

class Shop {
  String id;
  String name;
  String phone;
  String address;
  String route;
  String gstin;
  String state;
  double opening;

  Shop({
    required this.id,
    this.name = '',
    this.phone = '',
    this.address = '',
    this.route = '',
    this.gstin = '',
    this.state = '',
    this.opening = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'route': route,
    'gstin': gstin,
    'state': state,
    'opening': opening,
  };
  static Shop fromMap(Map<String, dynamic> m) => Shop(
    id: m['id'],
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    address: m['address'] ?? '',
    route: m['route'] ?? '',
    gstin: m['gstin'] ?? '',
    state: m['state'] ?? '',
    opening: num_(m['opening']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'route': route,
    'gstin': gstin,
    'state': state,
    'opening': opening,
  };
  static Shop fromJson(Map<String, dynamic> j) => Shop(
    id: j['id'],
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    address: j['address'] ?? '',
    route: j['route'] ?? '',
    gstin: j['gstin'] ?? '',
    state: j['state'] ?? '',
    opening: num_(j['opening']),
  );
}

class Product {
  String id;
  String name;
  String unit;
  String hsn;
  double price;
  double cost;
  double gst;
  double stock;
  double low;

  Product({
    required this.id,
    this.name = '',
    this.unit = 'pcs',
    this.hsn = '',
    this.price = 0,
    this.cost = 0,
    this.gst = 0,
    this.stock = 0,
    this.low = 5,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'unit': unit,
    'hsn': hsn,
    'price': price,
    'cost': cost,
    'gst': gst,
    'stock': stock,
    'low': low,
  };
  static Product fromMap(Map<String, dynamic> m) => Product(
    id: m['id'],
    name: m['name'] ?? '',
    unit: m['unit'] ?? 'pcs',
    hsn: m['hsn'] ?? '',
    price: num_(m['price']),
    cost: num_(m['cost']),
    gst: num_(m['gst']),
    stock: num_(m['stock']),
    low: num_(m['low']),
  );
  Map<String, dynamic> toJson() => toMap();
  static Product fromJson(Map<String, dynamic> j) => fromMap(j);
}

class InvoiceItem {
  String pid;
  String name;
  String hsn;
  String unit;
  double qty;
  double rate;
  double gst;
  double amt;
  double taxable;
  double cgst;
  double sgst;
  double igst;

  InvoiceItem({
    this.pid = '',
    this.name = '',
    this.hsn = '',
    this.unit = '',
    this.qty = 0,
    this.rate = 0,
    this.gst = 0,
    this.amt = 0,
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
  });

  Map<String, dynamic> toJson() => {
    'pid': pid,
    'name': name,
    'hsn': hsn,
    'unit': unit,
    'qty': qty,
    'rate': rate,
    'gst': gst,
    'amt': amt,
    'taxable': taxable,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
  };
  static InvoiceItem fromJson(Map<String, dynamic> j) => InvoiceItem(
    pid: j['pid'] ?? '',
    name: j['name'] ?? '',
    hsn: j['hsn'] ?? '',
    unit: j['unit'] ?? '',
    qty: num_(j['qty']),
    rate: num_(j['rate']),
    gst: num_(j['gst']),
    amt: num_(j['amt']),
    taxable: num_(j['taxable']),
    cgst: num_(j['cgst']),
    sgst: num_(j['sgst']),
    igst: num_(j['igst']),
  );
}

class Party {
  String name;
  String address;
  String gstin;
  String state;
  String phone;
  Party({this.name = '', this.address = '', this.gstin = '', this.state = '', this.phone = ''});
  Map<String, dynamic> toJson() =>
      {'name': name, 'address': address, 'gstin': gstin, 'state': state, 'phone': phone};
  static Party fromJson(Map<String, dynamic> j) => Party(
    name: j['name'] ?? '',
    address: j['address'] ?? '',
    gstin: j['gstin'] ?? '',
    state: j['state'] ?? '',
    phone: j['phone'] ?? '',
  );
}

class SignBlock {
  String name;
  String sig; // sig key
  int ts;
  String id;
  SignBlock({this.name = '', this.sig = '', this.ts = 0, this.id = ''});
  Map<String, dynamic> toJson() => {'name': name, 'sig': sig, 'ts': ts, 'id': id};
  static SignBlock fromJson(Map<String, dynamic> j) => SignBlock(
    name: j['name'] ?? '',
    sig: j['sig'] ?? '',
    ts: j['ts'] ?? 0,
    id: j['id'] ?? '',
  );
}

class Invoice {
  String id;
  String no;
  String date; // yyyy-mm-dd
  int ts;
  String type; // 'gst' | 'nongst'
  String shopId;
  String shopName;
  Party party;
  bool incl;
  List<InvoiceItem> items;
  double gross;
  double disc;
  double taxable;
  double cgst;
  double sgst;
  double igst;
  double round;
  double total;
  bool intra;
  String notes;
  String status; // 'pending' | 'delivered'
  bool cancelled;
  SignBlock? auth;
  SignBlock? recv;

  Invoice({
    required this.id,
    required this.no,
    required this.date,
    required this.ts,
    required this.type,
    this.shopId = '',
    this.shopName = 'Walk-in customer',
    Party? party,
    this.incl = false,
    List<InvoiceItem>? items,
    this.gross = 0,
    this.disc = 0,
    this.taxable = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.round = 0,
    this.total = 0,
    this.intra = true,
    this.notes = '',
    this.status = 'pending',
    this.cancelled = false,
    this.auth,
    this.recv,
  })  : party = party ?? Party(),
        items = items ?? [];

  bool get isGst => type == 'gst';

  Map<String, dynamic> toRowMap() => {
    'id': id,
    'no': no,
    'date': date,
    'ts': ts,
    'type': type,
    'shop_id': shopId,
    'shop_name': shopName,
    'party_json': jsonEncode(party.toJson()),
    'incl': incl ? 1 : 0,
    'gross': gross,
    'disc': disc,
    'taxable': taxable,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'round_off': round,
    'total': total,
    'intra': intra ? 1 : 0,
    'notes': notes,
    'status': status,
    'cancelled': cancelled ? 1 : 0,
    'auth_json': auth != null ? jsonEncode(auth!.toJson()) : null,
    'recv_json': recv != null ? jsonEncode(recv!.toJson()) : null,
  };

  static Invoice fromRow(Map<String, dynamic> m, List<InvoiceItem> items) => Invoice(
    id: m['id'],
    no: m['no'],
    date: m['date'],
    ts: m['ts'],
    type: m['type'],
    shopId: m['shop_id'] ?? '',
    shopName: m['shop_name'] ?? '',
    party: m['party_json'] != null ? Party.fromJson(jsonDecode(m['party_json'])) : Party(),
    incl: (m['incl'] ?? 0) == 1,
    items: items,
    gross: num_(m['gross']),
    disc: num_(m['disc']),
    taxable: num_(m['taxable']),
    cgst: num_(m['cgst']),
    sgst: num_(m['sgst']),
    igst: num_(m['igst']),
    round: num_(m['round_off']),
    total: num_(m['total']),
    intra: (m['intra'] ?? 1) == 1,
    notes: m['notes'] ?? '',
    status: m['status'] ?? 'pending',
    cancelled: (m['cancelled'] ?? 0) == 1,
    auth: m['auth_json'] != null ? SignBlock.fromJson(jsonDecode(m['auth_json'])) : null,
    recv: m['recv_json'] != null ? SignBlock.fromJson(jsonDecode(m['recv_json'])) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'no': no,
    'date': date,
    'ts': ts,
    'type': type,
    'shopId': shopId,
    'shopName': shopName,
    'party': party.toJson(),
    'incl': incl,
    'items': items.map((e) => e.toJson()).toList(),
    'gross': gross,
    'disc': disc,
    'taxable': taxable,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'round': round,
    'total': total,
    'intra': intra,
    'notes': notes,
    'status': status,
    'cancelled': cancelled,
    'auth': auth?.toJson(),
    'recv': recv?.toJson(),
  };

  static Invoice fromJson(Map<String, dynamic> j) => Invoice(
    id: j['id'],
    no: j['no'],
    date: j['date'],
    ts: j['ts'],
    type: j['type'],
    shopId: j['shopId'] ?? '',
    shopName: j['shopName'] ?? '',
    party: j['party'] != null ? Party.fromJson(j['party']) : Party(),
    incl: j['incl'] == true,
    items: (j['items'] as List? ?? []).map((e) => InvoiceItem.fromJson(e)).toList(),
    gross: num_(j['gross']),
    disc: num_(j['disc']),
    taxable: num_(j['taxable']),
    cgst: num_(j['cgst']),
    sgst: num_(j['sgst']),
    igst: num_(j['igst']),
    round: num_(j['round']),
    total: num_(j['total']),
    intra: j['intra'] != false,
    notes: j['notes'] ?? '',
    status: j['status'] ?? 'pending',
    cancelled: j['cancelled'] == true,
    auth: j['auth'] != null ? SignBlock.fromJson(j['auth']) : null,
    recv: j['recv'] != null ? SignBlock.fromJson(j['recv']) : null,
  );
}

class Payment {
  String id;
  String date;
  int ts;
  String shopId;
  String invoiceId;
  double amount;
  String mode;
  String note;

  Payment({
    required this.id,
    required this.date,
    required this.ts,
    this.shopId = '',
    this.invoiceId = '',
    this.amount = 0,
    this.mode = 'Cash',
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'ts': ts,
    'shop_id': shopId,
    'invoice_id': invoiceId,
    'amount': amount,
    'mode': mode,
    'note': note,
  };
  static Payment fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'],
    date: m['date'],
    ts: m['ts'],
    shopId: m['shop_id'] ?? '',
    invoiceId: m['invoice_id'] ?? '',
    amount: num_(m['amount']),
    mode: m['mode'] ?? 'Cash',
    note: m['note'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'ts': ts,
    'shopId': shopId,
    'invoiceId': invoiceId,
    'amount': amount,
    'mode': mode,
    'note': note,
  };
  static Payment fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'],
    date: j['date'],
    ts: j['ts'],
    shopId: j['shopId'] ?? '',
    invoiceId: j['invoiceId'] ?? '',
    amount: num_(j['amount']),
    mode: j['mode'] ?? 'Cash',
    note: j['note'] ?? '',
  );
}

class StockMove {
  String id;
  String pid;
  String date;
  int ts;
  double qty;
  String type; // in | out | adj
  String note;

  StockMove({
    required this.id,
    required this.pid,
    required this.date,
    required this.ts,
    this.qty = 0,
    this.type = 'in',
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'pid': pid,
    'date': date,
    'ts': ts,
    'qty': qty,
    'type': type,
    'note': note,
  };
  static StockMove fromMap(Map<String, dynamic> m) => StockMove(
    id: m['id'],
    pid: m['pid'],
    date: m['date'],
    ts: m['ts'],
    qty: num_(m['qty']),
    type: m['type'] ?? 'in',
    note: m['note'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'pid': pid,
    'date': date,
    'ts': ts,
    'qty': qty,
    'type': type,
    'note': note,
  };
  static StockMove fromJson(Map<String, dynamic> j) => StockMove(
    id: j['id'],
    pid: j['pid'],
    date: j['date'],
    ts: j['ts'],
    qty: num_(j['qty']),
    type: j['type'] ?? 'in',
    note: j['note'] ?? '',
  );
}