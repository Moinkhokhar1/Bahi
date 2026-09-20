import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';

const _ink = PdfColor.fromInt(0xFF131A35);
const _muted = PdfColor.fromInt(0xFF5A6383);
const _line = PdfColor.fromInt(0xFFDDE1EE);

final _fontBytes = <String, ByteData>{};

/// The PDF default font (Helvetica) has no glyph for the rupee sign or the
/// minus sign, so they print as a box. Noto Sans has both. The font files are
/// read once and reused; the font objects are built per document.
Future<pw.ThemeData> _loadPdfTheme() async {
  Future<pw.Font> font(String file) async {
    final data = _fontBytes[file] ??= await rootBundle.load('assets/fonts/$file');
    return pw.Font.ttf(data);
  }

  return pw.ThemeData.withFont(
    base: await font('NotoSans-Regular.ttf'),
    bold: await font('NotoSans-Bold.ttf'),
    italic: await font('NotoSans-Italic.ttf'),
  );
}

Future<Uint8List> buildInvoicePdf(AppState app, Invoice inv, {required bool challan}) async {
  final st = app.settings;
  final gst = inv.isGst;
  final pt = inv.party;
  final title = challan ? 'Delivery Challan' : (gst ? 'Tax Invoice' : 'Bill of Supply');
  final paidMap = app.paidMap();
  final paid = paidMap[inv.id] ?? 0;
  final due = inv.total - paid;

  pw.MemoryImage? authImg;
  pw.MemoryImage? recvImg;
  if (inv.auth != null) {
    final s = app.sigOf(inv.auth!.sig);
    if (s.isNotEmpty) authImg = pw.MemoryImage(base64Decode(s));
  }
  if (inv.recv != null) {
    final s = app.sigOf(inv.recv!.sig);
    if (s.isNotEmpty) recvImg = pw.MemoryImage(base64Decode(s));
  }
  final bahiIconData = await rootBundle.load('assets/icon/bill_icon.png');

  final bahiIcon = pw.MemoryImage(bahiIconData.buffer.asUint8List(),
  );

  final doc = pw.Document(theme: await _loadPdfTheme());

  pw.Widget cell(String t, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: pw.Text(t,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: _ink)),
  );

  final headers = <String>['#', 'Item', 'Qty', if (!challan) ...['Rate', if (gst) 'GST', 'Amount']];
  final rows = <List<String>>[];
  for (var i = 0; i < inv.items.length; i++) {
    final it = inv.items[i];
    rows.add([
      '${i + 1}',
      it.hsn.isNotEmpty ? '${it.name}\nHSN ${it.hsn}' : it.name,
      '${fq(it.qty)} ${it.unit}',
      if (!challan) ...[
        fnum(it.rate),
        if (gst) '${fq(it.gst)}%',
        fnum(it.amt),
      ],
    ]);
  }

  final totalsRows = <List<String>>[];
  if (!challan) {
    totalsRows.add(['Items total${inv.incl ? ' (incl. GST)' : ''}', fnum(inv.gross)]);
    if (inv.disc > 0) totalsRows.add(['Discount', '\u2212 ${fnum(inv.disc)}']);
    if (gst) {
      totalsRows.add(['Taxable value', fnum(inv.taxable)]);
      if (inv.intra) {
        totalsRows.add(['CGST', fnum(inv.cgst)]);
        totalsRows.add(['SGST', fnum(inv.sgst)]);
      } else {
        totalsRows.add(['IGST', fnum(inv.igst)]);
      }
    }
    if (inv.round.abs() >= 0.005) {
      totalsRows.add(['Round off', (inv.round < 0 ? '\u2212 ' : '+ ') + fnum(inv.round.abs())]);
    }
    totalsRows.add(['Total (₹)', fnum(inv.total)]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        if (inv.cancelled)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            margin: const pw.EdgeInsets.only(bottom: 8),
            color: const PdfColor.fromInt(0xFFFDE4E4),
            child: pw.Text('CANCELLED',
                style: pw.TextStyle(color: const PdfColor.fromInt(0xFFC43636), fontWeight: pw.FontWeight.bold)),
          ),
        // pw.Text(st.bizName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink)),
        // if (st.address.isNotEmpty) pw.Text(st.address, style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
        // pw.Text(
        //   [
        //     if (st.phone.isNotEmpty) 'Phone ${st.phone}',
        //     if (st.gstin.isNotEmpty && gst) 'GSTIN ${st.gstin}',
        //     if (st.state.isNotEmpty) stateName(st.state),
        //   ].join('    '),
        //   style: const pw.TextStyle(fontSize: 9.5, color: _muted),
        // ),
        // pw.SizedBox(height: 10),
        // pw.Container(
        //   alignment: pw.Alignment.center,
        //   padding: const pw.EdgeInsets.symmetric(vertical: 6),
        //   decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line), bottom: pw.BorderSide(color: _line))),
        //   child: pw.Text(title + (challan || !gst ? '' : ' (Original for recipient)'),
        //       style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
        // ),
        // pw.SizedBox(height: 10),
        // pw.Row(
        //   crossAxisAlignment: pw.CrossAxisAlignment.start,
        //   children: [
        //     pw.Expanded(
        //       child: pw.Column(
        //         crossAxisAlignment: pw.CrossAxisAlignment.start,
        //         children: [
        //           pw.Text('Bill to', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink)),
        //           pw.Text(pt.name, style: const pw.TextStyle(fontSize: 10.5, color: _ink)),
        //           if (pt.address.isNotEmpty) pw.Text(pt.address, style: const pw.TextStyle(fontSize: 9, color: _muted)),
        //           pw.Text(
        //             [
        //               if (pt.gstin.isNotEmpty) 'GSTIN ${pt.gstin}',
        //               if (pt.phone.isNotEmpty) 'Phone ${pt.phone}',
        //             ].join('   '),
        //             style: const pw.TextStyle(fontSize: 9, color: _muted),
        //           ),
        //           if (gst && pt.state.isNotEmpty)
        //             pw.Text('Place of supply: ${stateName(pt.state)} (${pt.state})',
        //                 style: const pw.TextStyle(fontSize: 9, color: _muted)),
        //         ],
        //       ),
        //     ),
        //     pw.Column(
        //       crossAxisAlignment: pw.CrossAxisAlignment.end,
        //       children: [
        //         pw.Text(inv.no, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: _ink)),
        //         pw.Text(fdate(inv.date), style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
        //       ],
        //     ),
        //   ],
        // ),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Business information
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    st.bizName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),

                  if (st.address.isNotEmpty)
                    pw.Text(
                      st.address,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: _muted,
                      ),
                    ),

                  pw.Text(
                    [
                      if (st.phone.isNotEmpty) 'Phone ${st.phone}',
                      if (st.gstin.isNotEmpty && gst) 'GSTIN ${st.gstin}',
                      if (st.state.isNotEmpty) stateName(st.state),
                    ].join('    '),
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),

            // Right: Bahi branding
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Image(
                  bahiIcon,
                  width: 42,
                  height: 42,
                  fit: pw.BoxFit.contain,
                ),

                pw.SizedBox(height: 3),

                pw.Text(
                  'Powered by Bahi',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F4FA)),
          cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
          border: pw.TableBorder.all(color: _line, width: 0.5),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            if (!challan) 3: pw.Alignment.centerRight,
            if (!challan && gst) 4: pw.Alignment.centerRight,
            if (!challan) (gst ? 5 : 4): pw.Alignment.centerRight,
          },
          cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        ),
        if (totalsRows.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: totalsRows
                    .map((r) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(r[0],
                          style: pw.TextStyle(
                              fontSize: 9.5,
                              color: _ink,
                              fontWeight: r[0].startsWith('Total') ? pw.FontWeight.bold : pw.FontWeight.normal)),
                      pw.Text(r[1],
                          style: pw.TextStyle(
                              fontSize: 9.5,
                              color: _ink,
                              fontWeight: r[0].startsWith('Total') ? pw.FontWeight.bold : pw.FontWeight.normal)),
                    ],
                  ),
                ))
                    .toList(),
              ),
            ),
          ),
        ],
        if (!challan) ...[
          pw.SizedBox(height: 10),
          pw.Text('Amount in words: Rupees ${words(inv.total)} Only',
              style: const pw.TextStyle(fontSize: 9, color: _muted, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Received: ${fnum(paid)}', style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
              pw.Text('Balance due: ${fnum(due < 0 ? 0 : due)}', style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
            ],
          ),
        ],
        if (inv.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('Note: ${inv.notes}', style: const pw.TextStyle(fontSize: 9, color: _muted)),
        ],
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (recvImg != null) pw.Image(recvImg, height: 46) else pw.SizedBox(height: 46),
                  pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line)))),
                  pw.Text('Received by${inv.recv?.name.isNotEmpty == true ? ': ${inv.recv!.name}' : ''}',
                      style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                  if (inv.recv != null) pw.Text(fdt(inv.recv!.ts), style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('For ${st.bizName}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                  if (authImg != null) pw.Image(authImg, height: 46) else pw.SizedBox(height: 46),
                  pw.Container(width: 140, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line)))),
                  pw.Text('Authorised signatory', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
                  if (inv.auth != null)
                    pw.Text('${inv.auth!.name} signed digitally on ${fdt(inv.auth!.ts)}\nSign ID ${inv.auth!.id}',
                        textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        if (!challan && (st.upi.isNotEmpty || st.bank.isNotEmpty)) ...[
          pw.SizedBox(height: 10),
          if (st.upi.isNotEmpty) pw.Text('UPI: ${st.upi}', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
          if (st.bank.isNotEmpty) pw.Text(st.bank, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        ],
        if (st.terms.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(st.terms, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        ],
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('This is a computer-generated document.',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ),
      ],
    ),
  );

  return doc.save();
}