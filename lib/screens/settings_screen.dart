import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart' hide round2;
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../widgets/signature_pad.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _biz = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  final _upi = TextEditingController();
  final _bank = TextEditingController();
  final _terms = TextEditingController();
  final _prefixG = TextEditingController();
  final _nextG = TextEditingController();
  final _prefixN = TextEditingController();
  final _nextN = TextEditingController();

  String _state = '';
  bool _gstReg = true;
  String _defType = 'gst';
  bool _incl = false;
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fill(context.read<AppState>().settings);
  }

  @override
  void dispose() {
    for (final t in [
      _biz, _owner, _phone, _address, _gstin, _upi, _bank, _terms, _prefixG, _nextG, _prefixN, _nextN
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  /// Copies saved settings into the form fields.
  void _fill(AppSettings s) {
    _biz.text = s.bizName;
    _owner.text = s.owner;
    _phone.text = s.phone;
    _address.text = s.address;
    _gstin.text = s.gstin;
    _upi.text = s.upi;
    _bank.text = s.bank;
    _terms.text = s.terms;
    _prefixG.text = s.prefixG;
    _nextG.text = '${s.nextG}';
    _prefixN.text = s.prefixN;
    _nextN.text = '${s.nextN}';
    _state = s.state;
    _gstReg = s.gstReg;
    _defType = s.defType;
    _incl = s.incl;
    _dirty = false;
  }

  void _touch() => setState(() => _dirty = true);

  /// Applies one change to the latest saved settings and saves it. Used by the
  /// options that take effect straight away (theme, PIN, signature).
  Future<void> _update(void Function(AppSettings s) change) async {
    final app = context.read<AppState>();
    final s = AppSettings.fromMap(app.settings.toMap());
    change(s);
    await app.saveSettings(s);
  }

  String _numberPreview(String prefix, String next) {
    final n = int.tryParse(next.trim()) ?? 1;
    return '${prefix.trim()}-${n.toString().padLeft(4, '0')}';
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final biz = _biz.text.trim();
    if (biz.isEmpty) {
      toastMsg(context, 'Enter your business name');
      return;
    }
    final g = _gstReg ? _gstin.text.trim().toUpperCase() : '';
    if (g.isNotEmpty && !GSTIN_RE.hasMatch(g)) {
      toastMsg(context, 'GSTIN should be 15 characters, like 27AAPFU0939F1ZV');
      return;
    }
    final pg = _prefixG.text.trim();
    final pn = _prefixN.text.trim();
    final ng = int.tryParse(_nextG.text.trim());
    final nn = int.tryParse(_nextN.text.trim());
    if (pg.isEmpty || pn.isEmpty) {
      toastMsg(context, 'Enter a prefix for your bill numbers');
      return;
    }
    if (ng == null || ng < 1 || nn == null || nn < 1) {
      toastMsg(context, 'Next bill numbers must be 1 or higher');
      return;
    }
    // Stop the next number from clashing with a bill that already exists.
    final gNo = _numberPreview(pg, '$ng');
    final nNo = _numberPreview(pn, '$nn');
    if (app.invoices.any((i) => i.no == gNo || i.no == nNo)) {
      toastMsg(context, 'A bill with the number ${app.invoices.any((i) => i.no == gNo) ? gNo : nNo} already exists. Choose a higher number.');
      return;
    }

    await _update((s) {
      s.bizName = biz;
      s.owner = _owner.text.trim();
      s.phone = _phone.text.trim();
      s.address = _address.text.trim();
      s.state = _state;
      s.gstReg = _gstReg;
      s.gstin = g;
      s.defType = _defType;
      s.incl = _incl;
      s.prefixG = pg;
      s.nextG = ng;
      s.prefixN = pn;
      s.nextN = nn;
      s.upi = _upi.text.trim();
      s.bank = _bank.text.trim();
      s.terms = _terms.text.trim();
    });
    if (!mounted) return;
    setState(() => _dirty = false);
    toastMsg(context, 'Settings saved');
  }

  // ------------------------------------------------------------------
  // signature
  // ------------------------------------------------------------------

  Future<void> _captureSignature() async {
    final data = await showSignatureSheet(
      context,
      title: 'Authorised signature',
      subtitle: 'This is printed on the bills you choose to sign.',
      okLabel: 'Save signature',
      onName: null,
    );
    if (data == null || data.isEmpty || !mounted) return;
    await context.read<AppState>().saveSignature(data);
    if (mounted) toastMsg(context, 'Signature saved');
  }

  Future<void> _removeSignature() async {
    final ok = await confirmSheet(context,
        message: 'Remove your saved signature? Bills already signed keep theirs.', okLabel: 'Remove', danger: true);
    if (!ok || !mounted) return;
    await context.read<AppState>().removeSignature();
  }

  // ------------------------------------------------------------------
  // PIN lock
  // ------------------------------------------------------------------

  Future<String?> _askPin(String title, {String? subtitle}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PinSheet(title: title, subtitle: subtitle),
    );
  }

  Future<void> _setPin({required bool change}) async {
    final app = context.read<AppState>();
    if (change) {
      final cur = await _askPin('Enter your current PIN');
      if (cur == null || !mounted) return;
      if (cur != app.settings.pin) {
        toastMsg(context, 'That PIN is not correct');
        return;
      }
    }
    final first = await _askPin(change ? 'Choose a new PIN' : 'Choose a 4-digit PIN',
        subtitle: 'You will need it each time you open the app.');
    if (first == null || !mounted) return;
    final again = await _askPin('Enter the PIN again');
    if (again == null || !mounted) return;
    if (again != first) {
      toastMsg(context, 'The two PINs did not match');
      return;
    }
    await _update((s) => s.pin = first);
    if (mounted) toastMsg(context, 'PIN saved');
  }

  Future<void> _removePin() async {
    final app = context.read<AppState>();
    final cur = await _askPin('Enter your current PIN');
    if (cur == null || !mounted) return;
    if (cur != app.settings.pin) {
      toastMsg(context, 'That PIN is not correct');
      return;
    }
    await _update((s) => s.pin = '');
    if (mounted) toastMsg(context, 'PIN removed');
  }

  // ------------------------------------------------------------------
  // data: backup / restore / sample / erase
  // ------------------------------------------------------------------

  Future<void> _backup() async {
    final app = context.read<AppState>();
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bahi-backup-${today()}.json');
      await file.writeAsString(app.backupJson());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Bahi backup ${fdate(today())}',
      );
    } catch (_) {
      if (mounted) toastMsg(context, 'Could not create the backup');
    }
  }

  Future<void> _restore() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RestoreSheet(),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final ok = await confirmSheet(context,
        message: 'Replace everything on this phone with this backup?', okLabel: 'Restore', danger: true);
    if (!ok || !mounted) return;
    final app = context.read<AppState>();
    final done = await app.restoreFromJson(text.trim());
    if (!mounted) return;
    if (done) {
      setState(() => _fill(app.settings));
      toastMsg(context, 'Backup restored');
    } else {
      toastMsg(context, 'That does not look like a Bahi backup');
    }
  }

  Future<void> _sample() async {
    final ok = await confirmSheet(context,
        message: 'Replace everything with demo shops, products and bills?', okLabel: 'Load demo data', danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    try {
      await app.loadSample();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _fill(app.settings);
        });
      }
    }
    if (mounted) toastMsg(context, 'Demo data loaded');
  }

  Future<void> _erase() async {
    final first = await confirmSheet(context,
        message: 'Erase all shops, products, bills and payments from this phone?', okLabel: 'Continue', danger: true);
    if (!first || !mounted) return;
    final second = await confirmSheet(context,
        message: 'This cannot be undone. Erase everything now?', okLabel: 'Erase everything', danger: true);
    if (!second || !mounted) return;
    await context.read<AppState>().eraseAll();
    if (!mounted) return;
    // The app goes back to the welcome screen, so leave Settings.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ------------------------------------------------------------------
  // build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = context.bahi;
    final s = app.settings;
    final sig = app.sigOf(s.sigKey);
    final hasPin = s.pin.isNotEmpty;
    final themeChoice = const ['auto', 'light', 'dark'].contains(s.theme) ? s.theme : 'auto';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmSheet(context,
            message: 'Leave without saving your changes?', okLabel: 'Discard changes', danger: true);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _save,
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
          ],
          bottom: _busy
              ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
              : null,
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: [
              // ---- business ----
              const SectionHeader('Your business'),
              _panel(context, [
                TextField(
                    controller: _biz,
                    textCapitalization: TextCapitalization.words,
                    decoration: bahiInput('Business name'),
                    onChanged: (_) => _touch()),
                fieldGap(),
                TextField(
                    controller: _owner,
                    textCapitalization: TextCapitalization.words,
                    decoration: bahiInput('Owner name'),
                    onChanged: (_) => _touch()),
                fieldGap(),
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: bahiInput('Phone'),
                    onChanged: (_) => _touch()),
                fieldGap(),
                TextField(
                    controller: _address,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: bahiInput('Address'),
                    onChanged: (_) => _touch()),
                fieldGap(),
                DropdownButtonFormField<String>(
                  key: ValueKey('state-$_state'),
                  initialValue: STATES.any((x) => x[0] == _state) ? _state : null,
                  isExpanded: true,
                  decoration: bahiInput('State (decides CGST + SGST or IGST)'),
                  items: STATES
                      .map((x) => DropdownMenuItem(value: x[0], child: Text('${x[1]} (${x[0]})', overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    _state = v ?? '';
                    _touch();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Registered under GST'),
                  value: _gstReg,
                  onChanged: (v) {
                    _gstReg = v;
                    _touch();
                  },
                ),
                if (_gstReg)
                  TextField(
                    controller: _gstin,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 15,
                    decoration: bahiInput('Your GSTIN'),
                    onChanged: (v) {
                      final up = v.toUpperCase();
                      if (up.length >= 2 && _state.isEmpty) {
                        final code = up.substring(0, 2);
                        if (STATES.any((x) => x[0] == code)) _state = code;
                      }
                      _touch();
                    },
                  ),
              ]),

              // ---- billing ----
              const SectionHeader('Billing'),
              _panel(context, [
                if (_gstReg) ...[
                  Text('New bills start as', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment(value: 'gst', label: Text('GST bill')),
                      ButtonSegment(value: 'nongst', label: Text('No GST bill')),
                    ],
                    selected: {_defType == 'nongst' ? 'nongst' : 'gst'},
                    onSelectionChanged: (v) {
                      _defType = v.first;
                      _touch();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prices already include GST'),
                    subtitle: const Text('New GST bills start with this ticked'),
                    value: _incl,
                    onChanged: (v) {
                      _incl = v;
                      _touch();
                    },
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                            controller: _prefixG,
                            textCapitalization: TextCapitalization.characters,
                            decoration: bahiInput('GST bill prefix'),
                            onChanged: (_) => _touch()),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                            controller: _nextG,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: bahiInput('Next no.'),
                            onChanged: (_) => _touch()),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text('Next GST bill: ${_numberPreview(_prefixG.text, _nextG.text)}',
                        style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                          controller: _prefixN,
                          textCapitalization: TextCapitalization.characters,
                          decoration: bahiInput('No-GST bill prefix'),
                          onChanged: (_) => _touch()),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _nextN,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: bahiInput('Next no.'),
                          onChanged: (_) => _touch()),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text('Next no-GST bill: ${_numberPreview(_prefixN.text, _nextN.text)}',
                      style: TextStyle(color: c.muted, fontSize: 12.5)),
                ),
                TextField(
                    controller: _terms,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: bahiInput('Terms printed on every bill'),
                    onChanged: (_) => _touch()),
              ]),

              // ---- getting paid ----
              const SectionHeader('Getting paid'),
              _panel(context, [
                TextField(
                    controller: _upi,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: bahiInput('UPI ID', hint: 'name@bank'),
                    onChanged: (_) => _touch()),
                fieldGap(),
                TextField(
                    controller: _bank,
                    maxLines: 2,
                    decoration: bahiInput('Bank details', hint: 'Bank, account number, IFSC'),
                    onChanged: (_) => _touch()),
              ]),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ElevatedButton(onPressed: _dirty ? _save : null, child: const Text('Save changes')),
              ),

              // ---- signature ----
              const SectionHeader('Authorised signature'),
              _panel(context, [
                if (sig.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.line),
                      ),
                      child: Builder(builder: (_) {
                        try {
                          return Image.memory(base64Decode(sig),
                              height: 70, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 70));
                        } catch (_) {
                          return const SizedBox(height: 70);
                        }
                      }),
                    ),
                  )
                else
                  Text('No signature saved yet. Add one and it can be printed on your bills.',
                      style: TextStyle(color: c.muted, fontSize: 13.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _captureSignature,
                        child: Text(sig.isNotEmpty ? 'Draw again' : 'Add signature'),
                      ),
                    ),
                    if (sig.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _removeSignature,
                          style: OutlinedButton.styleFrom(foregroundColor: c.red),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ],
                ),
              ]),

              // ---- appearance ----
              const SectionHeader('Appearance'),
              _panel(context, [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment(value: 'auto', label: Text('Auto')),
                    ButtonSegment(value: 'light', label: Text('Light')),
                    ButtonSegment(value: 'dark', label: Text('Dark')),
                  ],
                  selected: {themeChoice},
                  onSelectionChanged: (v) => _update((x) => x.theme = v.first),
                ),
                const SizedBox(height: 6),
                Text('Auto follows your phone\'s light or dark setting.',
                    style: TextStyle(color: c.muted, fontSize: 12.5)),
              ]),

              // ---- security ----
              const SectionHeader('App lock'),
              CardList(children: [
                if (!hasPin)
                  LiRow(
                    onTap: () => _setPin(change: false),
                    mainTop: const Text('Set a 4-digit PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    mainBottom: Text('Ask for it every time the app opens', style: TextStyle(color: c.muted, fontSize: 12.5)),
                    end: Icon(Icons.chevron_right, color: c.muted),
                  )
                else ...[
                  LiRow(
                    onTap: () => _setPin(change: true),
                    mainTop: const Text('Change PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    end: Icon(Icons.chevron_right, color: c.muted),
                  ),
                  LiRow(
                    onTap: _removePin,
                    mainTop: Text('Turn off PIN', style: TextStyle(fontWeight: FontWeight.w600, color: c.red)),
                  ),
                ],
              ]),

              // ---- data ----
              const SectionHeader('Your data'),
              CardList(children: [
                LiRow(
                  onTap: _backup,
                  mainTop: const Text('Back up data', style: TextStyle(fontWeight: FontWeight.w600)),
                  mainBottom: Text('Save a copy to Drive, WhatsApp or email', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  end: Icon(Icons.chevron_right, color: c.muted),
                ),
                LiRow(
                  onTap: _restore,
                  mainTop: const Text('Restore from backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  mainBottom: Text('Paste the text of a backup file', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  end: Icon(Icons.chevron_right, color: c.muted),
                ),
                LiRow(
                  onTap: _sample,
                  mainTop: const Text('Load demo data', style: TextStyle(fontWeight: FontWeight.w600)),
                  mainBottom: Text('Try the app with sample shops, products and bills', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  end: Icon(Icons.chevron_right, color: c.muted),
                ),
                LiRow(
                  onTap: _erase,
                  mainTop: Text('Erase all data', style: TextStyle(fontWeight: FontWeight.w600, color: c.red)),
                  mainBottom: Text('Deletes everything on this phone', style: TextStyle(color: c.muted, fontSize: 12.5)),
                ),
              ]),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'Bahi · version 1.0.0\nBills, stock and deliveries for shop-to-shop businesses. Your records are stored on this phone only, so back them up now and then.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, List<Widget> children) {
    final c = context.bahi;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

// ----------------------------------------------------------------------
// bottom sheets that own their text controllers
// ----------------------------------------------------------------------

class _PinSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  const _PinSheet({required this.title, this.subtitle});

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _c = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    if (_c.text.length != 4) {
      setState(() => _err = 'Enter 4 digits');
      return;
    }
    Navigator.pop(context, _c.text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(widget.subtitle!, style: TextStyle(color: c.muted, fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            autofocus: true,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w700),
            decoration: bahiInput('PIN').copyWith(errorText: _err, counterText: ''),
            onChanged: (_) {
              if (_err != null) setState(() => _err = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _submit, child: const Text('Continue')),
        ],
      ),
    );
  }
}

class _RestoreSheet extends StatefulWidget {
  const _RestoreSheet();

  @override
  State<_RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends State<_RestoreSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) setState(() => _c.text = data!.text!);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Restore from backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Open your backup file, copy all of its text, then paste it here.',
                style: TextStyle(color: c.muted, fontSize: 13.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              minLines: 5,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              decoration: bahiInput('Backup text'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _paste, child: const Text('Paste'))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _c.text),
                    child: const Text('Restore'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}