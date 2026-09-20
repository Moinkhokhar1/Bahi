import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show billRowTile;
import 'new_bill_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String q = '';
  String f = 'all';
  final filters = const [
    ['all', 'All'],
    ['deliver', 'To deliver'],
    ['unpaid', 'Unpaid'],
    ['gst', 'GST'],
    ['nogst', 'No GST'],
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final paid = app.paidMap();
    var list = [...app.invoices]..sort((a, b) => b.ts.compareTo(a.ts));
    if (q.isNotEmpty) {
      final ql = q.toLowerCase();
      list = list.where((i) => ('${i.no} ${i.shopName}').toLowerCase().contains(ql)).toList();
    }
    if (f != 'all') {
      list = list.where((i) {
        if (i.cancelled) return false;
        if (f == 'deliver') return i.status == 'pending';
        if (f == 'unpaid') return i.total - (paid[i.id] ?? 0) >= 0.5;
        if (f == 'gst') return i.isGst;
        if (f == 'nogst') return !i.isGst;
        return true;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.gold, foregroundColor: c.goldInk),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewBillScreen())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New bill'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Search by shop or bill number',
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: filters.map((x) {
                final on = f == x[0];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(x[1]),
                    selected: on,
                    onSelected: (_) => setState(() => f = x[0]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? EmptyState('Nothing here', sub: app.invoices.isEmpty ? 'Your bills will appear here.' : 'Try a different filter.')
                : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [CardList(children: list.map((i) => billRowTile(context, i, paid)).toList())],
            ),
          ),
        ],
      ),
    );
  }
}