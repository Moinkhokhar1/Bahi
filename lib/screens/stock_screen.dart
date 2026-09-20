import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';

void productDetailOpener(BuildContext context, String id) => openProductDetail(context, id);

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final val = sumBy(app.products, (Product p) => (p.stock > 0 ? p.stock : 0) * (p.cost != 0 ? p.cost : p.price));
    final low = app.products.where((p) => p.stock <= p.low).length;
    var list = [...app.products]..sort((a, b) => a.name.compareTo(b.name));
    if (q.isNotEmpty) {
      final ql = q.toLowerCase();
      list = list.where((p) => ('${p.name} ${p.hsn}').toLowerCase().contains(ql)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          TextButton(onPressed: () => openStockSheet(context), child: const Text('Stock in')),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.blue, foregroundColor: c.blueInk),
              onPressed: () => openProductSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Product'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              KpiCard(label: 'Stock value', value: money(val)),
              KpiCard(label: 'Items running low', value: '$low', valueColor: low > 0 ? c.red : null),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search products or HSN'),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
              app.products.isEmpty ? 'No products yet' : 'No match',
              sub: 'Add what you sell, with price, GST rate and stock.',
              action: app.products.isEmpty
                  ? ElevatedButton(onPressed: () => openProductSheet(context), child: const Text('Add product'))
                  : null,
            )
                : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                CardList(
                  children: list.map((p) {
                    return LiRow(
                      onTap: () => openProductDetail(context, p.id),
                      mainTop: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      mainBottom: Text('${money(p.price)} / ${p.unit}  ·  GST ${fq(p.gst)}%',
                          style: TextStyle(color: c.muted, fontSize: 12.5)),
                      end: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${fq(p.stock)} ${p.unit}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.stock <= 0 ? c.red : c.ink)),
                          if (p.stock <= p.low)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: p.stock <= 0 ? StatusChip.red(context, 'Out') : StatusChip.gold(context, 'Low'),
                            ),
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