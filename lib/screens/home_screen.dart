import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'bills_screen.dart';
import 'invoice_pdf_screen.dart';
import 'invoice_screen.dart';
import 'new_bill_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart' show productDetailOpener;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final t = today();
    final live = app.invoices.where((i) => !i.cancelled).toList();
    final td = live.where((i) => i.date == t).toList();
    final sales = sumBy(td, (i) => i.total);
    final coll = sumBy(app.payments.where((p) => p.date == t), (p) => p.amount);
    final recv = sumBy(app.shops, (s) => app.shopBal(s) > 0 ? app.shopBal(s) : 0);
    final pend = live.where((i) => i.status == 'pending').toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final low = app.products.where((p) => p.stock <= p.low).toList();
    final paid = app.paidMap();
    final recent = [...app.invoices]..sort((a, b) => b.ts.compareTo(a.ts));
    final recentTop = recent.take(5).toList();
    final setupIncomplete = app.products.isEmpty || app.shops.isEmpty || app.invoices.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.receipt_long_rounded, color: c.goldInk, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.settings.bizName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
                        Text(fdate(t), style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              decoration: BoxDecoration(
                color: c.blue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: c.ink.withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Billed today',
                            style: TextStyle(color: c.blueInk.withValues(alpha: .85), fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(money(sales),
                            style: TextStyle(
                                color: c.blueInk, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('${td.length} ${td.length == 1 ? 'bill' : 'bills'}',
                              style: TextStyle(color: c.blueInk.withValues(alpha: .9), fontSize: 13)),
                          const SizedBox(width: 16),
                          Text('${money(coll)} collected',
                              style: TextStyle(color: c.blueInk.withValues(alpha: .9), fontSize: 13)),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.blueInk.withValues(alpha: .28), width: 1.4))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('To collect from shops', style: TextStyle(color: c.blueInk.withValues(alpha: .8), fontSize: 12)),
                          Text(money(recv), style: TextStyle(color: c.blueInk, fontWeight: FontWeight.w700, fontSize: 18)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('Waiting for delivery', style: TextStyle(color: c.blueInk.withValues(alpha: .8), fontSize: 12)),
                          Text('${pend.length}', style: TextStyle(color: c.blueInk, fontWeight: FontWeight.w700, fontSize: 18)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Tile(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Receive',
                      onTap: () => openPaymentSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Tile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock in',
                      onTap: () => openStockSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Tile(
                      icon: Icons.storefront_outlined,
                      label: 'Add shop',
                      onTap: () => openShopSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Tile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (setupIncomplete)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Get started', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    _checkItem(context, 1, app.products.isNotEmpty, 'Add the products you sell', () => openProductSheet(context)),
                    _checkItem(context, 2, app.shops.isNotEmpty, 'Add the shops you deliver to', () => openShopSheet(context)),
                    _checkItem(context, 3, app.invoices.isNotEmpty, 'Make your first bill',
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewBillScreen()))),
                    _checkItem(context, 4, app.settings.sigKey.isNotEmpty, 'Save your authorised signature',
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                  ],
                ),
              ),
            if (pend.isNotEmpty) ...[
              const SectionHeader('Deliveries to make'),
              CardList(
                children: pend.take(4).map((i) {
                  final s = app.shopById(i.shopId);
                  return LiRow(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(id: i.id))),
                    mainTop: Text(i.shopName, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    mainBottom: Text('${i.no} · ${money(i.total)}${s != null && s.route.isNotEmpty ? ' · ${s.route}' : ''}',
                        style: TextStyle(color: c.muted, fontSize: 12.5)),
                    end: TextButton.icon(
                      style: TextButton.styleFrom(backgroundColor: c.goldSoft, foregroundColor: c.gold, padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(id: i.id))),
                      icon: const Icon(Icons.local_shipping_outlined, size: 16),
                      label: const Text('Deliver'),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (low.isNotEmpty) ...[
              const SectionHeader('Running low'),
              CardList(
                children: low.take(4).map((p) {
                  return LiRow(
                    onTap: () => productDetailOpener(context, p.id),
                    mainTop: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    mainBottom: Text('Alert at ${fq(p.low)} ${p.unit}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    end: Text('${fq(p.stock)} ${p.unit}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.stock <= 0 ? c.red : c.ink)),
                  );
                }).toList(),
              ),
            ],
            SectionHeader('Recent bills',
                actionLabel: 'See all',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillsScreen()))),
            recentTop.isEmpty
                ? const CardList(children: [Padding(padding: EdgeInsets.all(4), child: EmptyState('No bills yet', sub: 'Tap New bill to make your first one.'))])
                : CardList(children: recentTop.map((i) => billRowTile(context, i, paid)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _checkItem(BuildContext context, int n, bool done, String label, VoidCallback onTap) {
    final c = context.bahi;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: done ? c.green : c.line, borderRadius: BorderRadius.circular(11)),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, decoration: done ? TextDecoration.lineThrough : null, color: done ? c.muted : c.ink))),
          ],
        ),
      ),
    );
  }
}

Widget billRowTile(BuildContext context, Invoice i, Map<String, double> paid) {
  final c = context.bahi;
  final due = i.total - (paid[i.id] ?? 0);
  List<Widget> chips = [];
  if (i.cancelled) {
    chips.add(StatusChip.red(context, 'Cancelled'));
  } else {
    chips.add(i.isGst ? StatusChip.blue(context, 'GST') : StatusChip('No GST'));
    chips.add(i.status == 'delivered' ? StatusChip.green(context, 'Delivered') : StatusChip.gold(context, 'To deliver'));
    chips.add(due < 0.5 ? StatusChip.green(context, 'Paid') : ((paid[i.id] ?? 0) > 0 ? StatusChip.gold(context, 'Part paid') : StatusChip.red(context, 'Unpaid')));
  }
  return LiRow(
    dim: i.cancelled,
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceScreen(id: i.id))),
    mainTop: Text(i.shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
    mainBottom: Text('${i.no}  ·  ${fshort(i.date)}', style: TextStyle(color: c.muted, fontSize: 12.5)),
    end: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(money(i.total), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(spacing: 4, children: chips),
      ],
    ),
  );
}