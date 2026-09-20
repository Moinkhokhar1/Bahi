import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart' hide round2;
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'shop_detail_screen.dart';

enum _Period { today, week, month, lastMonth, fy, all, custom }

enum _Tab { sales, gst, shops, products, dues }

const _periodLabels = <_Period, String>{
  _Period.today: 'Today',
  _Period.week: 'Last 7 days',
  _Period.month: 'This month',
  _Period.lastMonth: 'Last month',
  _Period.fy: 'This year (Apr–Mar)',
  _Period.all: 'All time',
  _Period.custom: 'Pick dates',
};

const _tabLabels = <_Tab, String>{
  _Tab.sales: 'Sales',
  _Tab.gst: 'GST',
  _Tab.shops: 'Shops',
  _Tab.products: 'Products',
  _Tab.dues: 'Dues',
};

/// Small running-total helper used by the report tabs.
class _Agg {
  int n = 0;
  double amt = 0;
  double tax = 0;
  double qty = 0;
  double cost = 0; // cost of the items that have a known cost price
  double costed = 0; // sale value of those same items
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.month;
  _Tab _tab = _Tab.sales;
  String _customFrom = '';
  String _customTo = '';

  /// Inclusive ISO date bounds for the chosen period.
  (String, String) _bounds() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return (today(), today());
      case _Period.week:
        return (daysAgo(6), today());
      case _Period.month:
        return (isoOf(DateTime(now.year, now.month, 1)), today());
      case _Period.lastMonth:
        return (isoOf(DateTime(now.year, now.month - 1, 1)), isoOf(DateTime(now.year, now.month, 0)));
      case _Period.fy:
        final y = now.month >= 4 ? now.year : now.year - 1;
        return ('$y-04-01', today());
      case _Period.all:
        return ('0000-01-01', '9999-12-31');
      case _Period.custom:
        return (_customFrom, _customTo);
    }
  }

  String _rangeText(String from, String to) {
    if (_period == _Period.all) return 'Everything so far';
    if (from == to) return fdate(from);
    return '${fdate(from)} – ${fdate(to)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _period == _Period.custom && _customFrom.isNotEmpty
          ? DateTimeRange(start: DateTime.parse(_customFrom), end: DateTime.parse(_customTo))
          : null,
      helpText: 'Choose the dates for this report',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = _Period.custom;
      _customFrom = isoOf(picked.start);
      _customTo = isoOf(picked.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final (from, to) = _bounds();
    bool inRange(String d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0;

    final bills = app.invoices.where((i) => !i.cancelled && inRange(i.date)).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    final pays = app.payments.where((p) => inRange(p.date)).toList();
    final double sales = sumBy(bills, (Invoice i) => i.total);
    final double collected = sumBy(pays, (Payment p) => p.amount);
    final double receivable = sumBy(app.shops, (Shop s) => app.shopBal(s) > 0 ? app.shopBal(s) : 0.0);

    final List<Widget> body = switch (_tab) {
      _Tab.sales => _salesTab(context, bills, pays),
      _Tab.gst => _gstTab(context, bills),
      _Tab.shops => _shopsTab(context, app, bills, pays),
      _Tab.products => _productsTab(context, app, bills),
      _Tab.dues => _duesTab(context, app),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Export bills as CSV',
            onPressed: () => _export(context, bills, from, to),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _Period.values.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_periodLabels[p]!),
                    selected: _period == p,
                    onSelected: (_) => p == _Period.custom ? _pickRange() : setState(() => _period = p),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(_rangeText(from, to), style: TextStyle(color: c.muted, fontSize: 12.5)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              KpiCard(label: 'Billed', value: money(sales)),
              KpiCard(label: 'Received', value: money(collected), valueColor: c.green),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              KpiCard(label: 'Bills', value: '${bills.length}'),
              KpiCard(
                  label: 'To collect (now)',
                  value: money(receivable),
                  valueColor: receivable > 0 ? c.red : null),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _Tab.values.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tabLabels[t]!),
                    selected: _tab == t,
                    onSelected: (_) => setState(() => _tab = t),
                  ),
                );
              }).toList(),
            ),
          ),
          ...body,
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // tabs
  // ------------------------------------------------------------------

  List<Widget> _salesTab(BuildContext context, List<Invoice> bills, List<Payment> pays) {
    final c = context.bahi;
    if (bills.isEmpty && pays.isEmpty) {
      return [const EmptyState('Nothing in this period', sub: 'Try a longer period.')];
    }
    final byDay = <String, _Agg>{};
    for (final i in bills) {
      final a = byDay.putIfAbsent(i.date, () => _Agg());
      a.n++;
      a.amt += i.total;
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final gstBills = bills.where((i) => i.isGst).toList();
    final plainBills = bills.where((i) => !i.isGst).toList();
    final byMode = <String, double>{};
    for (final p in pays) {
      byMode[p.mode] = (byMode[p.mode] ?? 0.0) + p.amount;
    }
    final modes = byMode.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return [
      const SectionHeader('Bill types'),
      CardList(children: [
        _row(context, 'GST bills', _count(gstBills.length), money(sumBy(gstBills, (Invoice i) => i.total))),
        _row(context, 'No GST bills', _count(plainBills.length), money(sumBy(plainBills, (Invoice i) => i.total))),
      ]),
      const SectionHeader('Money received'),
      modes.isEmpty
          ? const CardList(children: [Padding(padding: EdgeInsets.all(4), child: EmptyState('No payments received'))])
          : CardList(children: modes.map((e) => _row(context, e.key, null, money(e.value), valueColor: c.green)).toList()),
      const SectionHeader('Day by day'),
      days.isEmpty
          ? const CardList(children: [Padding(padding: EdgeInsets.all(4), child: EmptyState('No bills in this period'))])
          : CardList(
        children: days.take(60).map((d) {
          final a = byDay[d]!;
          return _row(context, fdate(d), _count(a.n), money(a.amt));
        }).toList(),
      ),
      if (days.length > 60)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text('Showing the latest 60 days. Use a shorter period to see the rest.',
              style: TextStyle(color: c.muted, fontSize: 12.5)),
        ),
    ];
  }

  List<Widget> _gstTab(BuildContext context, List<Invoice> bills) {
    final c = context.bahi;
    final g = bills.where((i) => i.isGst).toList();
    if (g.isEmpty) {
      return [const EmptyState('No GST bills in this period', sub: 'GST figures come from bills made as GST bills.')];
    }
    final double taxable = sumBy(g, (Invoice i) => i.taxable);
    final double cgst = sumBy(g, (Invoice i) => i.cgst);
    final double sgst = sumBy(g, (Invoice i) => i.sgst);
    final double igst = sumBy(g, (Invoice i) => i.igst);
    final double tax = cgst + sgst + igst;

    final byRate = <double, _Agg>{};
    for (final i in g) {
      for (final it in i.items) {
        final a = byRate.putIfAbsent(it.gst, () => _Agg());
        a.amt += it.taxable;
        a.tax += it.cgst + it.sgst + it.igst;
      }
    }
    final rates = byRate.keys.toList()..sort();

    final b2b = g.where((i) => i.party.gstin.isNotEmpty).toList();
    final b2c = g.where((i) => i.party.gstin.isEmpty).toList();

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          KpiCard(label: 'Taxable value', value: money(taxable)),
          KpiCard(label: 'GST collected', value: money(tax)),
        ]),
      ),
      const SectionHeader('Tax collected'),
      CardList(children: [
        _row(context, 'CGST', null, money(cgst)),
        _row(context, 'SGST', null, money(sgst)),
        _row(context, 'IGST', null, money(igst)),
        _row(context, 'Total GST', null, money(tax)),
      ]),
      const SectionHeader('By GST rate'),
      CardList(
        children: rates.map((r) {
          final a = byRate[r]!;
          return _row(context, r == 0 ? 'GST 0% (nil rated)' : 'GST ${fq(r)}%', 'Taxable ${money(a.amt)}', money(a.tax),
              valueSub: 'tax');
        }).toList(),
      ),
      const SectionHeader('Who you billed'),
      CardList(children: [
        _row(context, 'GST-registered shops (B2B)',
            '${_count(b2b.length)} · taxable ${money(sumBy(b2b, (Invoice i) => i.taxable))}',
            money(sumBy(b2b, (Invoice i) => i.total))),
        _row(context, 'Unregistered shops and walk-ins (B2C)',
            '${_count(b2c.length)} · taxable ${money(sumBy(b2c, (Invoice i) => i.taxable))}',
            money(sumBy(b2c, (Invoice i) => i.total))),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Text('A summary for your own records. Check with your accountant before filing returns.',
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      ),
    ];
  }

  List<Widget> _shopsTab(BuildContext context, AppState app, List<Invoice> bills, List<Payment> pays) {
    final c = context.bahi;
    final billed = <String, _Agg>{};
    for (final i in bills) {
      final a = billed.putIfAbsent(i.shopId, () => _Agg());
      a.n++;
      a.amt += i.total;
    }
    final received = <String, double>{};
    for (final p in pays) {
      received[p.shopId] = (received[p.shopId] ?? 0.0) + p.amount;
    }
    final ids = <String>{...billed.keys, ...received.keys}.toList()
      ..sort((a, b) => (billed[b]?.amt ?? 0.0).compareTo(billed[a]?.amt ?? 0.0));
    if (ids.isEmpty) {
      return [const EmptyState('No shop activity in this period')];
    }
    return [
      const SectionHeader('Shop by shop'),
      CardList(
        children: ids.map((id) {
          final shop = id.isEmpty ? null : app.shopById(id);
          final name = id.isEmpty ? 'Walk-in customers' : (shop?.name ?? 'Deleted shop');
          final a = billed[id];
          final bal = shop != null ? app.shopBal(shop) : 0.0;
          return _row(
            context,
            name,
            '${_count(a?.n ?? 0)} · received ${money(received[id] ?? 0.0)}',
            money(a?.amt ?? 0.0),
            valueSub: bal > 0.5 ? 'owes ${money(bal)}' : null,
            onTap: shop == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopDetailScreen(id: shop.id))),
          );
        }).toList(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text('Amounts are what you billed in this period. "Owes" is the shop\'s balance today.',
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      ),
    ];
  }

  List<Widget> _productsTab(BuildContext context, AppState app, List<Invoice> bills) {
    final c = context.bahi;
    final agg = <String, _Agg>{};
    final names = <String, String>{};
    final units = <String, String>{};
    for (final i in bills) {
      for (final it in i.items) {
        final key = it.pid.isNotEmpty ? it.pid : it.name;
        final a = agg.putIfAbsent(key, () => _Agg());
        a.qty += it.qty;
        a.amt += it.taxable;
        final p = it.pid.isNotEmpty ? app.prodById(it.pid) : null;
        if (p != null && p.cost > 0) {
          a.cost += p.cost * it.qty;
          a.costed += it.taxable;
        }
        names[key] = it.name;
        units[key] = it.unit;
      }
    }
    if (agg.isEmpty) {
      return [const EmptyState('No products sold in this period')];
    }
    final keys = agg.keys.toList()..sort((a, b) => agg[b]!.amt.compareTo(agg[a]!.amt));
    final double profit = sumBy(agg.values, (_Agg a) => a.costed - a.cost);
    final double sold = sumBy(agg.values, (_Agg a) => a.amt);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          KpiCard(label: 'Sold (before GST)', value: money(sold)),
          KpiCard(label: 'Est. profit', value: money(profit), valueColor: profit < 0 ? c.red : c.green),
        ]),
      ),
      const SectionHeader('Best sellers'),
      CardList(
        children: keys.map((k) {
          final a = agg[k]!;
          final profitText = a.cost > 0 ? ' · est. profit ${money(a.costed - a.cost)}' : '';
          return _row(context, names[k] ?? k, '${fq(a.qty)} ${units[k] ?? ''} sold$profitText', money(a.amt));
        }).toList(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text('Profit uses each product\'s cost price as it is today, before GST. Products without a cost price are left out of it.',
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      ),
    ];
  }

  List<Widget> _duesTab(BuildContext context, AppState app) {
    final c = context.bahi;
    final owing = app.shops.where((s) => app.shopBal(s) > 0.5).toList()
      ..sort((a, b) => app.shopBal(b).compareTo(app.shopBal(a)));
    final double total = sumBy(owing, (Shop s) => app.shopBal(s));
    final double advance = sumBy(app.shops.where((s) => app.shopBal(s) < -0.5), (Shop s) => -app.shopBal(s));

    final paid = app.paidMap();
    final buckets = <double>[0.0, 0.0, 0.0];
    final oldest = <String, int>{};
    for (final i in app.invoices) {
      if (i.cancelled || i.shopId.isEmpty) continue;
      final double due = i.total - (paid[i.id] ?? 0.0);
      if (due < 0.5) continue;
      final age = _ageDays(i.date);
      buckets[age <= 7 ? 0 : (age <= 30 ? 1 : 2)] += due;
      if (age > (oldest[i.shopId] ?? -1)) oldest[i.shopId] = age;
    }

    if (owing.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            KpiCard(label: 'To collect', value: money(0)),
            KpiCard(label: 'Advance held', value: money(advance)),
          ]),
        ),
        const EmptyState('Nobody owes you anything', sub: 'Shops with a balance will be listed here.'),
      ];
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(children: [
          KpiCard(label: 'To collect', value: money(total), valueColor: c.red),
          KpiCard(label: 'Advance held', value: money(advance)),
        ]),
      ),
      const SectionHeader('Unpaid bills by age'),
      CardList(children: [
        _row(context, 'Up to 7 days', null, money(buckets[0])),
        _row(context, '8 to 30 days', null, money(buckets[1])),
        _row(context, 'Over 30 days', null, money(buckets[2]), valueColor: buckets[2] > 0.5 ? c.red : null),
      ]),
      const SectionHeader('Shops that owe you'),
      CardList(
        children: owing.map((s) {
          final age = oldest[s.id];
          return _row(
            context,
            s.name,
            age != null ? 'Oldest unpaid bill is ${age == 1 ? '1 day' : '$age days'} old' : (s.route.isNotEmpty ? s.route : null),
            money(app.shopBal(s)),
            valueColor: c.red,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopDetailScreen(id: s.id))),
          );
        }).toList(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text('Dues are as of today, whichever period is selected. Ageing covers bills only, not opening balances.',
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      ),
    ];
  }

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------

  String _count(int n) => '$n ${n == 1 ? 'bill' : 'bills'}';

  int _ageDays(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  }

  Widget _row(
      BuildContext context,
      String title,
      String? sub,
      String value, {
        Color? valueColor,
        String? valueSub,
        VoidCallback? onTap,
      }) {
    final c = context.bahi;
    return LiRow(
      onTap: onTap,
      mainTop: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      mainBottom: sub == null ? null : Text(sub, style: TextStyle(color: c.muted, fontSize: 12.5)),
      end: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
          if (valueSub != null) Text(valueSub, style: TextStyle(color: c.muted, fontSize: 11.5)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // CSV export (opens the phone's share sheet)
  // ------------------------------------------------------------------

  String _q(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  Future<void> _export(BuildContext context, List<Invoice> bills, String from, String to) async {
    if (bills.isEmpty) {
      toastMsg(context, 'No bills in this period to export');
      return;
    }
    final paid = context.read<AppState>().paidMap();
    final list = [...bills]..sort((a, b) => a.ts.compareTo(b.ts));
    final sb = StringBuffer('\uFEFF');
    sb.writeln('Date,Bill no,Type,Party,GSTIN,State,Items total,Discount,Taxable,CGST,SGST,IGST,Round off,Total,Received,Delivery');
    for (final i in list) {
      final p = paid[i.id] ?? 0.0;
      sb.writeln([
        i.date,
        _q(i.no),
        i.isGst ? 'GST' : 'No GST',
        _q(i.party.name.isNotEmpty ? i.party.name : i.shopName),
        _q(i.party.gstin),
        _q(i.party.state.isNotEmpty ? stateName(i.party.state) : ''),
        i.gross.toStringAsFixed(2),
        i.disc.toStringAsFixed(2),
        i.taxable.toStringAsFixed(2),
        i.cgst.toStringAsFixed(2),
        i.sgst.toStringAsFixed(2),
        i.igst.toStringAsFixed(2),
        i.round.toStringAsFixed(2),
        i.total.toStringAsFixed(2),
        p.toStringAsFixed(2),
        i.status == 'delivered' ? 'Delivered' : 'Pending',
      ].join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final label = _period == _Period.all ? 'all-time' : '${from}_to_$to';
      final file = File('${dir.path}/bahi-bills-$label.csv');
      await file.writeAsString(sb.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Bills ${_rangeText(from, to)}',
      );
    } catch (_) {
      if (context.mounted) toastMsg(context, 'Could not create the export');
    }
  }
}