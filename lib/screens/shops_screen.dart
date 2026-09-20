import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'shop_detail_screen.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});
  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final due = sumBy(app.shops, (Shop s) => app.shopBal(s) > 0 ? app.shopBal(s) : 0);
    var list = [...app.shops]..sort((a, b) => app.shopBal(b).compareTo(app.shopBal(a)));
    if (q.isNotEmpty) {
      final ql = q.toLowerCase();
      list = list.where((s) => ('${s.name} ${s.route} ${s.phone}').toLowerCase().contains(ql)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shops'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.blue, foregroundColor: c.blueInk),
              onPressed: () => openShopSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add shop'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              KpiCard(label: 'Total to collect', value: money(due), valueColor: due > 0 ? c.red : null),
              KpiCard(label: 'Shops', value: '${app.shops.length}'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search shops or areas'),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
              app.shops.isEmpty ? 'No shops yet' : 'No match',
              sub: 'Add the shops you deliver to. Each keeps its own account.',
              action: app.shops.isEmpty
                  ? ElevatedButton(onPressed: () => openShopSheet(context), child: const Text('Add shop'))
                  : null,
            )
                : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                CardList(
                  children: list.map((s) {
                    final b = app.shopBal(s);
                    return LiRow(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopDetailScreen(id: s.id))),
                      mainTop: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      mainBottom: Text(s.route.isNotEmpty ? '${s.route}  ·  ${s.gstin.isNotEmpty ? 'GSTIN added' : 'No GSTIN'}' : (s.gstin.isNotEmpty ? 'GSTIN added' : 'No GSTIN'),
                          style: TextStyle(color: c.muted, fontSize: 12.5)),
                      end: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(b.abs()),
                              style: TextStyle(fontWeight: FontWeight.w700, color: b > 0.5 ? c.red : (b < -0.5 ? c.green : c.ink))),
                          Text(b > 0.5 ? 'to collect' : (b < -0.5 ? 'advance' : 'settled'),
                              style: TextStyle(color: c.muted, fontSize: 11.5)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}