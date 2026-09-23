import 'dart:convert';
import '../widgets/celebration.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart' show Printing;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart' hide round2;
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../widgets/signature_pad.dart';
import 'invoice_pdf_screen.dart' show buildInvoicePdf;

/// One bill: items, tax split, payments, delivery and signatures.
///
/// Used as `InvoiceScreen(id: ...)` by the home, shop-detail and new-bill
/// screens. `InvoiceScreen.startDelivery` opens the "goods received" sheet
/// (called right after a bill is saved with "deliver now" ticked).
class InvoiceScreen extends StatelessWidget {
  final String id;
  const InvoiceScreen({super.key, required this.id});

  /// Asks for the receiver's name + signature and marks the bill delivered.
  static Future<void> startDelivery(BuildContext context, String id) async {
    final app = context.read<AppState>();
    final inv = app.invById(id);
    if (inv == null || inv.cancelled || inv.status == 'delivered') return;
    var recvName = '';
    final sig = await showSignatureSheet(
      context,
      title: 'Goods received',
      subtitle: 'Ask ${inv.shopName} to sign below, or skip if nobody is there to sign.',
      okLabel: 'Mark delivered',
      skipLabel: 'Deliver without signature',
      nameField: true,
      nameLabel: 'Received by (name)',
      onName: (n) => recvName = n,
    );
    if (sig == null) return; // sheet dismissed
    await app.deliverInvoice(id, recvName: recvName, sigData: sig);
    if (context.mounted) {
      await showDeliveredCelebration(
        context,
        billNo: inv.no,
        shopName: inv.shopName.isNotEmpty ? inv.shopName : 'Walk-in customer',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final inv = app.invById(id);
    if (inv == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox());
    }

    final double paid = app.paidMap()[inv.id] ?? 0.0;
    final double due = inv.total - paid;
    final canCollect = !inv.cancelled && due >= 0.5 && inv.shopId.isNotEmpty;
    final linked = app.payments.where((p) => p.invoiceId == inv.id).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    final double linkedTotal = sumBy(linked, (Payment p) => p.amount);
    final pt = inv.party;

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.no),
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            onPressed: () => _pdf(context, inv),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(context, v, inv, due),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'print', child: Text('Print')),
              const PopupMenuItem(value: 'challan', child: Text('Share delivery challan')),
              const PopupMenuItem(value: 'whatsapp', child: Text('Send on WhatsApp')),
              if (!inv.cancelled) const PopupMenuItem(value: 'cancel', child: Text('Cancel bill')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: inv.cancelled
          ? null
          : SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: c.paper,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              if (canCollect) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => openPaymentSheet(context, invoiceId: inv.id),
                    icon: const Icon(Icons.currency_rupee, size: 16),
                    label: const Text('Receive payment'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pdf(context, inv),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share bill'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          if (inv.cancelled)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'This bill is cancelled. Its stock went back on the shelf and it no longer counts in your reports.',
                style: TextStyle(color: c.red, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),

          // ---- header ----
          _panel(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(inv.isGst ? 'Tax invoice' : 'Bill of supply',
                          style: TextStyle(color: c.muted, fontSize: 12.5)),
                    ),
                    Text(fdate(inv.date), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(money(inv.total),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: c.ink,
                        decoration: inv.cancelled ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: _chips(context, inv, paid)),
                if (!inv.cancelled) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _mini(context, 'Received', money(paid), c.green)),
                      Expanded(
                        child: _mini(context, 'Balance due', money(due < 0.5 ? 0.0 : due),
                            due < 0.5 ? c.ink : c.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ---- bill to ----
          _panel(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bill to', style: TextStyle(color: c.muted, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(pt.name.isNotEmpty ? pt.name : inv.shopName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (pt.address.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(pt.address)),
                if (pt.gstin.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('GSTIN ${pt.gstin}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ),
                if (inv.isGst && pt.state.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Place of supply: ${stateName(pt.state)} (${pt.state}) · ${inv.intra ? 'CGST + SGST' : 'IGST'}',
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                  ),
                if (pt.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse('tel:${pt.phone}')),
                      child: Text(pt.phone, style: TextStyle(color: c.blue, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),

          // ---- items ----
          SectionHeader('Items (${inv.items.length})'),
          CardList(
            children: inv.items.map((it) {
              final parts = <String>['${fq(it.qty)} ${it.unit} × ${money(it.rate)}'];
              if (inv.isGst) parts.add('GST ${fq(it.gst)}%');
              if (it.hsn.isNotEmpty) parts.add('HSN ${it.hsn}');
              return LiRow(
                mainTop: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                mainBottom: Text(parts.join('  ·  '), style: TextStyle(color: c.muted, fontSize: 12.5)),
                end: Text(money(it.amt), style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // ---- totals ----
          _panel(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, inv.incl ? 'Items total (incl. GST)' : 'Items total', money(inv.gross)),
                if (inv.disc > 0) _kv(context, 'Discount', '\u2212 ${money(inv.disc)}'),
                if (inv.isGst) ...[
                  _kv(context, 'Taxable value', money(inv.taxable)),
                  if (inv.intra) ...[
                    _kv(context, 'CGST', money(inv.cgst)),
                    _kv(context, 'SGST', money(inv.sgst)),
                  ] else
                    _kv(context, 'IGST', money(inv.igst)),
                ],
                if (inv.round.abs() >= 0.005)
                  _kv(context, 'Round off', (inv.round < 0 ? '\u2212 ' : '+ ') + money(inv.round.abs())),
                const Divider(height: 22),
                _kv(context, 'Total', money(inv.total), bold: true),
                const SizedBox(height: 6),
                Text('Rupees ${words(inv.total)} only',
                    style: TextStyle(color: c.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

          // ---- payments ----
          if (linked.isNotEmpty || paid > 0.005) ...[
            const SectionHeader('Payments'),
            if (linked.isNotEmpty)
              CardList(
                children: linked.map((p) {
                  return LiRow(
                    mainTop: Text('Received (${p.mode})', style: const TextStyle(fontWeight: FontWeight.w600)),
                    mainBottom: Text(
                      p.note.isNotEmpty ? '${fdate(p.date)} · ${p.note}' : fdate(p.date),
                      style: TextStyle(color: c.muted, fontSize: 12.5),
                    ),
                    end: Text(money(p.amount), style: TextStyle(fontWeight: FontWeight.w700, color: c.green)),
                  );
                }).toList(),
              ),
            if (paid - linkedTotal > 0.5)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  '${money(paid - linkedTotal)} of this bill was covered by other payments received from this shop.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ),
          ],

          // ---- delivery ----
          const SectionHeader('Delivery'),
          _panel(
            context,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(inv.status),
                child: _deliveryBody(context, app, inv),
              ),
            ),
          ),

          // ---- authorised signature ----
          if (inv.auth != null)
            _panel(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Authorised signatory', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(inv.auth!.name.isNotEmpty ? inv.auth!.name : app.settings.bizName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    'Signed digitally on ${fdt(inv.auth!.ts)}${inv.auth!.id.isNotEmpty ? '\nSign ID ${inv.auth!.id}' : ''}',
                    style: TextStyle(color: c.muted, fontSize: 12.5),
                  ),
                  _sigImage(app.sigOf(inv.auth!.sig)),
                ],
              ),
            ),

          // ---- notes ----
          if (inv.notes.isNotEmpty)
            _panel(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(inv.notes),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // pieces
  // ------------------------------------------------------------------

  Widget _deliveryBody(BuildContext context, AppState app, Invoice inv) {
    final c = context.bahi;
    if (inv.cancelled) {
      return Text('Not delivered. This bill was cancelled.', style: TextStyle(color: c.muted));
    }
    if (inv.status == 'delivered') {
      final r = inv.recv;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: c.green, size: 20),
              const SizedBox(width: 8),
              const Text('Delivered', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          if (r != null) ...[
            const SizedBox(height: 6),
            Text(
              'Received by ${r.name.isNotEmpty ? r.name : 'the shop'} · ${fdt(r.ts)}',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            if (app.sigOf(r.sig).isNotEmpty)
              _sigImage(app.sigOf(r.sig))
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('No signature taken', style: TextStyle(color: c.muted, fontSize: 12.5)),
              ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: c.gold, size: 20),
            const SizedBox(width: 8),
            const Text('Waiting for delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: c.gold, foregroundColor: c.goldInk),
          onPressed: () => InvoiceScreen.startDelivery(context, inv.id),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark as delivered'),
        ),
      ],
    );
  }

  List<Widget> _chips(BuildContext context, Invoice inv, double paid) {
    if (inv.cancelled) return [StatusChip.red(context, 'Cancelled')];
    final due = inv.total - paid;
    return [
      inv.isGst ? StatusChip.blue(context, 'GST') : const StatusChip('No GST'),
      inv.status == 'delivered'
          ? StatusChip.green(context, 'Delivered')
          : StatusChip.gold(context, 'To deliver'),
      due < 0.5
          ? StatusChip.green(context, 'Paid')
          : (paid > 0 ? StatusChip.gold(context, 'Part paid') : StatusChip.red(context, 'Unpaid')),
    ];
  }

  Widget _panel(BuildContext context, {required Widget child}) {
    final c = context.bahi;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }

  Widget _mini(BuildContext context, String label, String value, Color color) {
    final c = context.bahi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool bold = false}) {
    final c = context.bahi;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  color: bold ? c.ink : c.muted,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 16 : 14)),
          Text(v,
              style: TextStyle(
                  color: c.ink,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 18 : 14)),
        ],
      ),
    );
  }

  /// Signatures are dark ink on transparent PNG, so show them on white.
  Widget _sigImage(String data) {
    if (data.isEmpty) return const SizedBox.shrink();
    try {
      final bytes = base64Decode(data);
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE1EE)),
          ),
          child: Image.memory(
            bytes,
            height: 70,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  // ------------------------------------------------------------------
  // actions
  // ------------------------------------------------------------------

  Future<void> _menu(BuildContext context, String v, Invoice inv, double due) async {
    switch (v) {
      case 'print':
        await _pdf(context, inv, print: true);
        break;
      case 'challan':
        await _pdf(context, inv, challan: true);
        break;
      case 'whatsapp':
        await _whatsapp(context, inv, due);
        break;
      case 'cancel':
        final ok = await confirmSheet(
          context,
          message:
          "Cancel ${inv.no}? Its stock goes back and it leaves your reports. Payments already received stay on the shop's account.",
          okLabel: 'Cancel bill',
          danger: true,
        );
        if (!ok || !context.mounted) return;
        await context.read<AppState>().cancelInvoice(inv.id);
        if (context.mounted) toastMsg(context, '${inv.no} cancelled');
        break;
    }
  }

  Future<void> _pdf(BuildContext context, Invoice inv, {bool challan = false, bool print = false}) async {
    final app = context.read<AppState>();
    try {
      final bytes = await buildInvoicePdf(app, inv, challan: challan);
      final name = '${challan ? 'Challan' : 'Invoice'}-${inv.no}'.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      if (print) {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      }
    } catch (_) {
      if (context.mounted) toastMsg(context, 'Could not create the PDF. Please try again.');
    }
  }

  Future<void> _whatsapp(BuildContext context, Invoice inv, double due) async {
    final st = context.read<AppState>().settings;
    final who = inv.party.name.isNotEmpty ? inv.party.name : inv.shopName;
    final b = StringBuffer('Hello $who, here is your bill ${inv.no} dated ${fdate(inv.date)} from ${st.bizName}. ');
    b.write('Total ${money(inv.total)}.');
    if (due >= 0.5) {
      b.write(' Balance due ${money(due)}.');
      if (st.upi.isNotEmpty) b.write(' Pay by UPI: ${st.upi}.');
    }
    b.write(' Thank you.');
    var p = inv.party.phone.replaceAll(RegExp(r'\D'), '');
    if (p.length == 10) p = '91$p';
    final uri = Uri.parse('https://wa.me/${p.length >= 11 ? p : ''}?text=${Uri.encodeComponent(b.toString())}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) toastMsg(context, 'Could not open WhatsApp');
    } catch (_) {
      if (context.mounted) toastMsg(context, 'Could not open WhatsApp');
    }
  }
}