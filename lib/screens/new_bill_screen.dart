import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/calc.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../widgets/signature_pad.dart';
import 'invoice_pdf_screen.dart';

class NewBillScreen extends StatefulWidget {
  final String? shopId;
  const NewBillScreen({super.key, this.shopId});

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  late String type;
  String shopId = '';
  bool walk = false;
  List<DraftItem> items = [];
  String discount = '';
  bool incl = false;
  String paidNow = '';
  String mode = 'Cash';
  bool deliverNow = true;
  bool attachSig = false;
  String notes = '';
  bool saving = false;

  final discountC = TextEditingController();
  final paidC = TextEditingController();
  final notesC = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final st = app.settings;
    type = (st.gstReg && st.defType == 'gst') ? 'gst' : 'nongst';
    incl = st.incl;
    attachSig = st.sigKey.isNotEmpty;
    shopId = widget.shopId ?? '';
  }

  CalcResult _calc(AppState app) {
    final shop = shopId.isNotEmpty ? app.shopById(shopId) : null;
    return calcBill(
      type: type,
      items: items,
      discount: discount,
      inclGst: incl,
      sellerState: app.settings.state,
      shopState: shop?.state,
    );
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (items.isEmpty) return true;
    return confirmSheet(context, message: 'Discard this bill?', okLabel: 'Discard', danger: true);
  }

  Future<void> _pickShop(AppState app) async {
    String q = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final list = app.shops.where((s) => q.isEmpty || ('${s.name} ${s.route}').toLowerCase().contains(q.toLowerCase())).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Deliver to', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search shops'),
                  onChanged: (v) => setSt(() => q = v),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      LiRow(
                        mainTop: const Text('Walk-in customer', style: TextStyle(fontWeight: FontWeight.w600)),
                        mainBottom: Text('Cash sale, no account', style: TextStyle(color: context.bahi.muted, fontSize: 12.5)),
                        onTap: () {
                          setState(() {
                            shopId = '';
                            walk = true;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                      ...list.map((s) {
                        final b = app.shopBal(s);
                        return LiRow(
                          mainTop: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          mainBottom: Text(s.route, style: TextStyle(color: context.bahi.muted, fontSize: 12.5)),
                          end: b > 0.5 ? Text('owes ${money(b)}', style: TextStyle(color: context.bahi.red, fontSize: 12)) : null,
                          onTap: () {
                            setState(() {
                              shopId = s.id;
                              walk = false;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openShopSheet(context, fromBill: true, onSaved: (id) => setState(() {
                      shopId = id;
                      walk = false;
                    }));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add a new shop'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _pickProduct(AppState app) async {
    if (app.products.isEmpty) {
      await _customItem();
      return;
    }
    String q = '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final list = app.products.where((p) => q.isEmpty || ('${p.name} ${p.hsn}').toLowerCase().contains(q.toLowerCase())).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search products'),
                  onChanged: (v) => setSt(() => q = v),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: list.isEmpty
                      ? const EmptyState('No products match')
                      : ListView(
                    children: list.map((p) {
                      final ex = items.where((x) => x.pid == p.id).isNotEmpty;
                      return LiRow(
                        mainTop: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        mainBottom: Text('${money(p.price)} / ${p.unit}  ·  ${fq(p.stock)} in stock',
                            style: TextStyle(color: p.stock <= 0 ? context.bahi.red : context.bahi.muted, fontSize: 12.5)),
                        end: ex ? StatusChip.blue(context, 'Added') : null,
                        onTap: () {
                          setSt(() {});
                          setState(() {
                            final existing = items.where((x) => x.pid == p.id);
                            if (existing.isNotEmpty) {
                              existing.first.qty = '${num_(existing.first.qty) + 1}';
                            } else {
                              items.add(DraftItem(pid: p.id, name: p.name, hsn: p.hsn, unit: p.unit, qty: '1', rate: '${p.price}', gst: p.gst));
                            }
                          });
                          toastMsg(context, 'Added ${p.name}');
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _customItem();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add an item not in stock list'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _customItem() async {
    final nameC = TextEditingController();
    final qtyC = TextEditingController(text: '1');
    final unitC = TextEditingController(text: 'pcs');
    final rateC = TextEditingController();
    final hsnC = TextEditingController();
    double gst = 18;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Custom item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 12),
                TextField(controller: nameC, decoration: bahiInput('Item name')),
                fieldGap(),
                Row(children: [
                  Expanded(child: TextField(controller: qtyC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: bahiInput('Quantity'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: unitC, decoration: bahiInput('Unit'))),
                ]),
                fieldGap(),
                Row(children: [
                  Expanded(child: TextField(controller: rateC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: bahiInput('Rate ₹'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: gst,
                      decoration: bahiInput('GST rate'),
                      items: GSTR.map((r) => DropdownMenuItem(value: r.toDouble(), child: Text('$r%'))).toList(),
                      onChanged: (v) => setSt(() => gst = v ?? 0),
                    ),
                  ),
                ]),
                fieldGap(),
                TextField(controller: hsnC, keyboardType: TextInputType.number, decoration: bahiInput('HSN code (optional)')),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    if (nameC.text.trim().isEmpty) {
                      toastMsg(context, 'Enter the item name');
                      return;
                    }
                    setState(() {
                      items.add(DraftItem(
                        name: nameC.text.trim(),
                        hsn: hsnC.text.trim(),
                        unit: unitC.text.trim(),
                        qty: qtyC.text.isEmpty ? '1' : qtyC.text,
                        rate: rateC.text.isEmpty ? '0' : rateC.text,
                        gst: gst,
                      ));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add to bill'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final shop = shopId.isNotEmpty ? app.shopById(shopId) : null;
    final gst = type == 'gst';
    final calc = _calc(app);
    final paid = (shopId.isEmpty && walk) ? calc.total : (num_(paidNow)).clamp(0, calc.total).toDouble();
    final due = calc.total - paid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (await _confirmDiscardIfNeeded() && context.mounted) Navigator.of(context).pop();
          },
        ),
        title: const Text('New bill'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (app.settings.gstReg)
                  Row(children: [
                    Expanded(
                      child: ChoiceChip(label: const Text('GST invoice'), selected: gst, onSelected: (_) => setState(() => type = 'gst')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(label: const Text('Bill without GST'), selected: !gst, onSelected: (_) => setState(() => type = 'nongst')),
                    ),
                  ]),
                const SizedBox(height: 6),
                Text(
                  gst
                      ? 'Tax invoice with GST. Tax splits into CGST + SGST for same-state shops and IGST for other states.'
                      : 'Bill of Supply. No tax is added or shown on this bill.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _pickShop(app),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                    child: Row(children: [
                      Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: c.blueSoft, borderRadius: BorderRadius.circular(11)),
                          child: Icon(Icons.storefront_outlined, color: c.blue, size: 19)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deliver to', style: TextStyle(color: c.muted, fontSize: 11.5)),
                            Text(shop?.name ?? (walk ? 'Walk-in customer' : 'Choose a shop'),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.muted),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                    child: Text('No items yet. Add the stock you are delivering.', style: TextStyle(color: c.muted, fontSize: 13)),
                  )
                else
                  ...List.generate(items.length, (i) => _itemCard(context, app, i, calc)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickProduct(app),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add item'),
                ),
                const SizedBox(height: 18),
                const Text('Discount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: discountC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: bahiInput('Discount ₹'),
                      onChanged: (v) => setState(() => discount = v),
                    ),
                  ),
                  if (gst) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: incl,
                        onChanged: (v) => setState(() => incl = v ?? false),
                        title: const Text('Rates incl. GST', style: TextStyle(fontSize: 12.5)),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                _summaryCard(context, calc, gst, paid, due),
                const SizedBox(height: 18),
                const Text('Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: paidC,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: bahiInput('Amount received now (₹)', hint: '0 if on credit'),
                        onChanged: (v) => setState(() => paidNow = v),
                        enabled: !(shopId.isEmpty && walk),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              paidNow = '${calc.total}';
                              paidC.text = paidNow;
                            }),
                            child: const Text('Full amount'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              paidNow = '';
                              paidC.text = '';
                            }),
                            child: const Text('On credit'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: mode,
                        decoration: bahiInput('Paid by'),
                        items: const ['Cash', 'UPI', 'Bank transfer', 'Cheque']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() => mode = v ?? 'Cash'),
                      ),
                      if (shopId.isEmpty && walk)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Walk-in bills are treated as paid in full.', style: TextStyle(color: c.muted, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: deliverNow,
                    onChanged: (v) => setState(() => deliverNow = v ?? true),
                    title: const Text('I am delivering now. Ask the shop to sign on receipt', style: TextStyle(fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Authorised signature', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (app.settings.sigKey.isNotEmpty) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: attachSig,
                          onChanged: (v) => setState(() => attachSig = v ?? false),
                          title: Text('Sign this bill as ${app.settings.owner.isNotEmpty ? app.settings.owner : app.settings.bizName}', style: const TextStyle(fontSize: 13)),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ] else ...[
                        Text('Add a signature once and it is stamped on every bill you authorise.', style: TextStyle(color: c.muted, fontSize: 12.5)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final data = await showSignatureSheet(context,
                                title: 'Your authorised signature',
                                subtitle: 'This is stamped on bills you authorise, with your name, the time and a sign ID.',
                                okLabel: 'Save signature',
                                onName: null);
                            if (data != null && data.isNotEmpty) {
                              await app.saveSignature(data);
                              setState(() => attachSig = true);
                            }
                          },
                          icon: const Icon(Icons.draw_outlined, size: 16),
                          label: const Text('Draw signature'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesC,
                  maxLines: 2,
                  decoration: bahiInput('Notes on the bill (optional)'),
                  onChanged: (v) => setState(() => notes = v),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.line))),
              child: Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bill total', style: TextStyle(color: c.muted, fontSize: 11.5)),
                    Text(money(calc.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: saving ? null : () => _save(app),
                    child: Text(saving ? 'Saving...' : 'Save bill'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(BuildContext context, AppState app, int i, CalcResult calc) {
    final c = context.bahi;
    final it = items[i];
    final gst = type == 'gst';
    final p = it.pid.isNotEmpty ? app.prodById(it.pid) : null;
    final short = p != null && num_(it.qty) > p.stock;
    final line = calc.lines.length > i ? calc.lines[i] : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => items.removeAt(i)),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Qty${it.unit.isNotEmpty ? ' (${it.unit})' : ''}', style: TextStyle(fontSize: 11, color: c.muted)),
                    Row(children: [
                      InkWell(
                        onTap: () => setState(() => it.qty = fq(round2(num_(it.qty) - 1).clamp(0, double.infinity))),
                        child: Container(width: 28, height: 32, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)), child: const Text('\u2212')),
                      ),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: it.qty)..selection = TextSelection.collapsed(offset: it.qty.length),
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6), border: InputBorder.none),
                          onChanged: (v) => setState(() => it.qty = v),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => it.qty = fq(round2(num_(it.qty) + 1))),
                        child: Container(width: 28, height: 32, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)), child: const Text('+')),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: it.rate)..selection = TextSelection.collapsed(offset: it.rate.length),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: bahiInput('Rate ₹'),
                  onChanged: (v) => setState(() => it.rate = v),
                ),
              ),
              if (gst) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: it.gst,
                    decoration: bahiInput('GST'),
                    items: GSTR.map((r) => DropdownMenuItem(value: r.toDouble(), child: Text('$r%'))).toList(),
                    onChanged: (v) => setState(() => it.gst = v ?? 0),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                p != null ? (short ? 'Only ${fq(p.stock)} ${p.unit} in stock' : '${fq(p.stock)} ${p.unit} in stock') : 'Custom item',
                style: TextStyle(fontSize: 11.5, color: short ? c.red : c.muted),
              ),
              Text(money(line?.amt ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, CalcResult calc, bool gst, double paid, double due) {
    final c = context.bahi;
    final rows = <List<String>>[
      ['Items total${gst && incl ? ' (incl. GST)' : ''}', money(calc.gross)],
      if (calc.disc > 0) ['Discount', '\u2212 ${money(calc.disc)}'],
      if (gst) ...[
        ['Taxable value', money(calc.taxable)],
        if (calc.intra) ...[
          ['CGST', money(calc.cgst)],
          ['SGST', money(calc.sgst)],
        ] else
          ['IGST', money(calc.igst)],
      ],
      if (calc.round.abs() >= 0.005) ['Round off', (calc.round < 0 ? '\u2212 ' : '+ ') + money(calc.round.abs())],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r[0], style: TextStyle(color: c.muted, fontSize: 13)), Text(r[1], style: const TextStyle(fontSize: 13))]),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(money(calc.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          Text(gst ? (calc.intra ? 'Same-state supply: CGST + SGST' : 'Other-state supply: IGST') : 'No GST on this bill',
              style: TextStyle(color: c.muted, fontSize: 11.5)),
          const Divider(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Received now', style: TextStyle(color: c.muted, fontSize: 13)), Text(money(paid), style: const TextStyle(fontSize: 13))]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Balance due', style: TextStyle(color: due > 0.5 ? c.red : c.muted, fontSize: 13, fontWeight: due > 0.5 ? FontWeight.w700 : FontWeight.w400)),
            Text(money(due), style: TextStyle(fontWeight: FontWeight.w700, color: due > 0.5 ? c.red : c.ink)),
          ]),
        ],
      ),
    );
  }

  Future<void> _save(AppState app) async {
    if (shopId.isEmpty && !walk) {
      toastMsg(context, 'Choose the shop first');
      return;
    }
    if (items.isEmpty) {
      toastMsg(context, 'Add at least one item');
      return;
    }
    if (items.any((i) => num_(i.qty) <= 0)) {
      toastMsg(context, 'Every item needs a quantity above zero');
      return;
    }
    final short = items.where((i) {
      final p = i.pid.isNotEmpty ? app.prodById(i.pid) : null;
      return p != null && num_(i.qty) > p.stock;
    }).toList();
    if (short.isNotEmpty) {
      final ok = await confirmSheet(context,
          message: 'Stock is short for ${short.map((x) => x.name).join(', ')}. Save the bill anyway?', okLabel: 'Save anyway');
      if (!ok) return;
    }
    setState(() => saving = true);
    try {
      final inv = await app.commitInvoice(
        type: type,
        shopId: shopId,
        walk: walk,
        items: items,
        discount: discount,
        incl: incl,
        paidNow: paidNow,
        mode: mode,
        notes: notes,
        attachSig: attachSig,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => InvoiceScreen(id: inv.id)));
      toastMsg(context, 'Bill ${inv.no} saved');
      if (deliverNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) InvoiceScreen.startDelivery(context, inv.id);
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}