import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart' hide round2;
import '../widgets/common.dart';

Future<bool> confirmSheet(
    BuildContext context, {
      required String message,
      required String okLabel,
      bool danger = false,
    }) async {
  final c = context.bahi;
  final res = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Go back'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: danger
                      ? ElevatedButton.styleFrom(backgroundColor: c.red, foregroundColor: Colors.white)
                      : null,
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(okLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return res ?? false;
}

void toastMsg(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// ---------------- Shop form ----------------
Future<void> openShopSheet(BuildContext context, {String? id, bool fromBill = false, void Function(String shopId)? onSaved}) async {
  final app = context.read<AppState>();
  final existing = id != null ? app.shopById(id) : null;
  final nameC = TextEditingController(text: existing?.name ?? '');
  final phoneC = TextEditingController(text: existing?.phone ?? '');
  final addrC = TextEditingController(text: existing?.address ?? '');
  final routeC = TextEditingController(text: existing?.route ?? '');
  final gstinC = TextEditingController(text: existing?.gstin ?? '');
  final openC = TextEditingController(text: existing != null && existing.opening != 0 ? fq(existing.opening) : '');
  String state = existing?.state ?? '';

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return Padding(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existing != null ? 'Edit shop' : 'Add shop',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: nameC, decoration: bahiInput('Shop name')),
              fieldGap(),
              TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: bahiInput('Phone (for WhatsApp)')),
              fieldGap(),
              TextField(controller: addrC, maxLines: 2, decoration: bahiInput('Address')),
              fieldGap(),
              TextField(controller: routeC, decoration: bahiInput('Route or area (optional)', hint: 'e.g. Market road, Monday run')),
              fieldGap(),
              TextField(
                controller: gstinC,
                textCapitalization: TextCapitalization.characters,
                maxLength: 15,
                decoration: bahiInput('GSTIN (leave empty if unregistered)'),
                onChanged: (v) {
                  final up = v.toUpperCase();
                  if (up.length >= 2 && state.isEmpty) {
                    final c = up.substring(0, 2);
                    if (STATES.any((s) => s[0] == c)) setState(() => state = c);
                  }
                },
              ),
              fieldGap(),
              DropdownButtonFormField<String>(
                initialValue: state.isEmpty ? null : state,
                decoration: bahiInput('State'),
                items: STATES
                    .map((s) => DropdownMenuItem(value: s[0], child: Text('${s[1]} (${s[0]})')))
                    .toList(),
                onChanged: (v) => setState(() => state = v ?? ''),
              ),
              fieldGap(),
              TextField(
                  controller: openC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: bahiInput('Amount they already owe you (₹)', hint: '0')),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (existing != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          if (app.shopHasInvoices(existing.id)) {
                            toastMsg(context, 'This shop has bills, so it cannot be deleted');
                            return;
                          }
                          Navigator.pop(ctx);
                          final ok = await confirmSheet(context,
                              message: 'Delete ${existing.name}?', okLabel: 'Delete', danger: true);
                          if (ok) {
                            await app.deleteShop(existing.id);
                          }
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                        child: const Text('Delete'),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameC.text.trim();
                        if (name.isEmpty) {
                          toastMsg(context, 'Enter the shop name');
                          return;
                        }
                        final g = gstinC.text.trim().toUpperCase();
                        if (g.isNotEmpty && !GSTIN_RE.hasMatch(g)) {
                          toastMsg(context, 'GSTIN should be 15 characters, like 27AAPFU0939F1ZV');
                          return;
                        }
                        final shop = Shop(
                          id: existing?.id ?? uid(),
                          name: name,
                          phone: phoneC.text.trim(),
                          address: addrC.text.trim(),
                          route: routeC.text.trim(),
                          gstin: g,
                          state: state,
                          opening: round2(num_(openC.text)),
                        );
                        await app.saveShop(shop);
                        Navigator.pop(ctx);
                        toastMsg(context, 'Shop saved');
                        onSaved?.call(shop.id);
                      },
                      child: const Text('Save shop'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }),
  );
}

/// ---------------- Product form ----------------
Future<void> openProductSheet(BuildContext context, {String? id}) async {
  final app = context.read<AppState>();
  final existing = id != null ? app.prodById(id) : null;
  final nameC = TextEditingController(text: existing?.name ?? '');
  final hsnC = TextEditingController(text: existing?.hsn ?? '');
  final priceC = TextEditingController(text: existing != null ? fq(existing.price) : '');
  final costC = TextEditingController(text: existing != null && existing.cost != 0 ? fq(existing.cost) : '');
  final lowC = TextEditingController(text: existing != null ? fq(existing.low) : '5');
  final stockC = TextEditingController();
  String unit = existing?.unit ?? 'pcs';
  double gst = existing?.gst ?? (app.settings.gstReg ? 18 : 0);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return Padding(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existing != null ? 'Edit product' : 'Add product',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: nameC, decoration: bahiInput('Product name')),
              fieldGap(),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: bahiInput('Unit'),
                    items: UNITS.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => unit = v ?? 'pcs'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: hsnC,
                        keyboardType: TextInputType.number,
                        decoration: bahiInput('HSN code (optional)'))),
              ]),
              fieldGap(),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: priceC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: bahiInput('Selling price ₹'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: costC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: bahiInput('Buying price ₹ (optional)'))),
              ]),
              fieldGap(),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: gst,
                    decoration: bahiInput('GST rate'),
                    items: GSTR.map((r) => DropdownMenuItem(value: r.toDouble(), child: Text('$r%'))).toList(),
                    onChanged: (v) => setState(() => gst = v ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: lowC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: bahiInput('Warn me at or below'))),
              ]),
              if (existing == null) ...[
                fieldGap(),
                TextField(
                    controller: stockC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: bahiInput('Stock you have now')),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (existing != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await confirmSheet(context,
                              message: 'Delete ${existing.name}? Old bills keep their item names.',
                              okLabel: 'Delete',
                              danger: true);
                          if (ok) await app.deleteProduct(existing.id);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
                        child: const Text('Delete'),
                      ),
                    )
                  else
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameC.text.trim();
                        if (name.isEmpty) {
                          toastMsg(context, 'Enter the product name');
                          return;
                        }
                        final prod = Product(
                          id: existing?.id ?? uid(),
                          name: name,
                          unit: unit,
                          hsn: hsnC.text.trim(),
                          price: round2(num_(priceC.text)),
                          cost: round2(num_(costC.text)),
                          gst: gst,
                          stock: existing?.stock ?? num_(stockC.text),
                          low: num_(lowC.text),
                        );
                        await app.saveProduct(prod, openingStock: existing == null ? num_(stockC.text) : null);
                        Navigator.pop(ctx);
                        toastMsg(context, 'Product saved');
                      },
                      child: const Text('Save product'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }),
  );
}

/// ---------------- Stock in/out ----------------
Future<void> openStockSheet(BuildContext context, {String? productId}) async {
  final app = context.read<AppState>();
  String? pid = productId;
  final qtyC = TextEditingController();
  final costC = TextEditingController();
  final noteC = TextEditingController();
  bool isIn = true;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return Padding(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Stock in or out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: pid,
                decoration: bahiInput('Product'),
                items: app.products
                    .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${fq(p.stock)} ${p.unit})')))
                    .toList(),
                onChanged: (v) => setState(() => pid = v),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Add stock'),
                    selected: isIn,
                    onSelected: (_) => setState(() => isIn = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Reduce stock'),
                    selected: !isIn,
                    onSelected: (_) => setState(() => isIn = false),
                  ),
                ),
              ]),
              fieldGap(),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: qtyC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: bahiInput('Quantity'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                        controller: costC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: bahiInput('Buying price ₹ (optional)'))),
              ]),
              fieldGap(),
              TextField(controller: noteC, decoration: bahiInput('Note', hint: 'Supplier, damaged, correction...')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (pid == null) {
                    toastMsg(context, 'Choose a product');
                    return;
                  }
                  final q = num_(qtyC.text);
                  if (q <= 0) {
                    toastMsg(context, 'Enter a quantity');
                    return;
                  }
                  await app.stockAdjust(
                    pid: pid!,
                    qty: q,
                    isIn: isIn,
                    cost: costC.text.isNotEmpty ? num_(costC.text) : null,
                    note: noteC.text.trim(),
                  );
                  Navigator.pop(ctx);
                  toastMsg(context, 'Stock updated');
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

/// ---------------- Payment ----------------
Future<void> openPaymentSheet(BuildContext context, {String? shopId, String? invoiceId}) async {
  final app = context.read<AppState>();
  final inv = invoiceId != null ? app.invById(invoiceId) : null;
  final paid = app.paidMap();
  String? sid = shopId ?? inv?.shopId;
  double def = 0;
  if (inv != null) {
    def = ((inv.total - (paid[inv.id] ?? 0)).clamp(0, double.infinity)).toDouble();
  } else if (sid != null && sid.isNotEmpty) {
    final s = app.shopById(sid);
    if (s != null) def = (app.shopBal(s)).clamp(0, double.infinity).toDouble();
  }
  final amtC = TextEditingController(text: def > 0 ? fq(round2(def)) : '');
  final noteC = TextEditingController();
  String mode = 'Cash';
  const modes = ['Cash', 'UPI', 'Bank transfer', 'Cheque'];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return Padding(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Receive payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: sid,
                decoration: bahiInput('From shop'),
                items: app.shops.map((s) {
                  final b = app.shopBal(s);
                  return DropdownMenuItem(
                      value: s.id, child: Text(s.name + (b > 0.5 ? ' (owes ${money(b)})' : '')));
                }).toList(),
                onChanged: (v) => setState(() => sid = v),
              ),
              fieldGap(),
              TextField(
                  controller: amtC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: bahiInput('Amount ₹')),
              fieldGap(),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: bahiInput('Paid by'),
                items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => mode = v ?? 'Cash'),
              ),
              fieldGap(),
              TextField(controller: noteC, decoration: bahiInput('Note (optional)')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (sid == null) {
                    toastMsg(context, 'Choose the shop');
                    return;
                  }
                  final a = num_(amtC.text);
                  if (a <= 0) {
                    toastMsg(context, 'Enter the amount received');
                    return;
                  }
                  await app.addPayment(
                    shopId: sid!,
                    amount: a,
                    mode: mode,
                    note: noteC.text.trim(),
                    invoiceId: invoiceId ?? '',
                  );
                  Navigator.pop(ctx);
                  toastMsg(context, '${money(a)} received');
                },
                child: const Text('Save payment'),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

/// ---------------- Product detail sheet ----------------
Future<void> openProductDetail(BuildContext context, String id) async {
  final app = context.read<AppState>();
  final p = app.prodById(id);
  if (p == null) return;
  final mv = app.moves.where((m) => m.pid == id).toList()
    ..sort((a, b) => b.ts.compareTo(a.ts));
  final recent = mv.take(6).toList();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.bahi;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 12),
              Row(children: [
                KpiCard(label: 'In stock', value: '${fq(p.stock)} ${p.unit}', valueColor: p.stock <= 0 ? c.red : null),
                KpiCard(label: 'Selling price', value: money(p.price)),
              ]),
              const SizedBox(height: 10),
              Text(
                [
                  if (p.hsn.isNotEmpty) 'HSN ${p.hsn}.',
                  'GST ${fq(p.gst)}%.',
                  if (p.cost > 0) 'Bought at ${money(p.cost)}.',
                ].join(' '),
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: c.gold, foregroundColor: c.goldInk),
                    onPressed: () {
                      Navigator.pop(ctx);
                      openStockSheet(context, productId: p.id);
                    },
                    child: const Text('Stock in or out'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openProductSheet(context, id: p.id);
                    },
                    child: const Text('Edit'),
                  ),
                ),
              ]),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Recent movement', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...recent.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${fshort(m.date)}   ${m.note}', style: TextStyle(color: c.muted, fontSize: 13))),
                      Text(
                        '${m.qty > 0 ? '+' : ''}${fq(m.qty)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: m.qty < 0 ? c.red : c.green),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      );
    },
  );
}