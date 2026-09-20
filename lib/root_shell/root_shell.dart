import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/bills_screen.dart';
import '../screens/stock_screen.dart';
import '../screens/shops_screen.dart';
import '../screens/new_bill_screen.dart';
import '../theme.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _idx = 0;

  final _pages = const [HomeScreen(), BillsScreen(), StockScreen(), ShopsScreen()];

  void _newBill() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewBillScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _newBill,
        backgroundColor: c.gold,
        foregroundColor: c.goldInk,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: c.card,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, Icons.home_rounded, 'Home', 0),
              _navItem(context, Icons.receipt_long_rounded, 'Bills', 1),
              const SizedBox(width: 40),
              _navItem(context, Icons.inventory_2_rounded, 'Stock', 2),
              _navItem(context, Icons.storefront_rounded, 'Shops', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int i) {
    final c = context.bahi;
    final on = _idx == i;
    return InkWell(
      onTap: () => setState(() => _idx = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: on ? c.blue : c.muted, size: 23),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: on ? c.blue : c.muted, fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}