import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'invoice_pdf_screen.dart';
import 'new_bill_screen.dart';

class _LedgerEntry {
  final int ts;
  final String title;
  final String date;
  final double dr;
  final double cr;
  final String? invId;
  double run = 0;
  _LedgerEntry({required this.ts, required this.title, required this.date, this.dr = 0, this.cr = 0, this.invId});
}

String _waLink(String phone, String text) {
  var p = phone.replaceAll(RegExp(r'\D'), '');
  if (p.length == 10) p = '91$p';
  return 'https://wa.me/${p.length >= 11 ? p : ''}?text=${Uri.encodeComponent(text)}';
}

class ShopDetailScreen extends StatelessWidget {
  final String id;
  const ShopDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final s = app.shopById(id);
    if (s == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox());
    }
    final bal = app.shopBal(s);
    final entries = <_LedgerEntry>[];
    if (s.opening != 0) {
      entries.add(_LedgerEntry(ts: 0, title: 'Opening balance', date: '', dr: s.opening));
    }
    for (final i in app.invoices.where((i) => i.shopId == s.id && !i.cancelled)) {
      entries.add(_LedgerEntry(ts: i.ts, title: i.no, date: i.date, dr: i.total, invId: i.id));
    }
    for (final p in app.payments.where((p) => p.shopId == s.id)) {
      entries.add(_LedgerEntry(ts: p.ts, title: 'Payment received (${p.mode})', date: p.date, cr: p.amount));
    }
    entries.sort((a, b) => a.ts.compareTo(b.ts));
    double run = 0;
    for (final e in entries) {
      run += e.dr - e.cr;
      e.run = run;
    }
    final reversed = entries.reversed.toList();
    final text =
        'Hello ${s.name}, this is a reminder from ${app.settings.bizName}. Your balance is ${money(bal)}.${app.settings.upi.isNotEmpty ? ' Pay by UPI: ${app.settings.upi}.' : ''} Thank you.';

    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [IconButton(onPressed: () => openShopSheet(context, id: s.id), icon: const Icon(Icons.edit_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bal > 0.5 ? 'To collect' : (bal < -0.5 ? 'Advance with you' : 'Account settled'),
                    style: TextStyle(color: c.muted, fontSize: 12.5)),
                Text(money(bal.abs()),
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: bal > 0.5 ? c.red : (bal < -0.5 ? c.green : c.ink))),
                if (s.address.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.address)),
                if (s.route.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Route: ${s.route}', style: TextStyle(color: c.muted, fontSize: 12.5))),
                if (s.gstin.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('GSTIN ${s.gstin}${s.state.isNotEmpty ? ' (${stateName(s.state)})' : ''}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ),
                if (s.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse('tel:${s.phone}')),
                      child: Text(s.phone, style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: c.gold, foregroundColor: c.goldInk),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewBillScreen(shopId: s.id))),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New bill'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => openPaymentSheet(context, shopId: s.id),
                      icon: const Icon(Icons.currency_rupee, size: 16),
                      label: const Text('Receive payment'),
                    ),
                  ),
                ]),
                if (bal > 0.5) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(_waLink(s.phone, text)), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Send payment reminder on WhatsApp'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader('Account statement'),
          entries.isEmpty
              ? const CardList(children: [Padding(padding: EdgeInsets.all(4), child: EmptyState('No activity yet', sub: 'Bills and payments for this shop will show here.'))])
              : CardList(
            children: reversed.map((e) {
              return LiRow(
                onTap: e.invId != null ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(id: e.invId!))) : null,
                mainTop: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                mainBottom: Text(e.date.isNotEmpty ? fdate(e.date) : 'Before Bahi', style: TextStyle(color: c.muted, fontSize: 12.5)),
                end: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(e.dr > 0 ? '+ ${money(e.dr)}' : '\u2212 ${money(e.cr)}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: e.dr > 0 ? c.ink : c.green)),
                    Text('Balance ${money(e.run)}', style: TextStyle(color: c.muted, fontSize: 11.5)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}