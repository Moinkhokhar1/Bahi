import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'models/models.dart';
import 'root_shell/root_shell.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'utils/format.dart' hide round2;
import 'widgets/common.dart';
import 'widgets/sheets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const BahiApp(),
    ),
  );
}

class BahiApp extends StatelessWidget {
  const BahiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only rebuild the MaterialApp when the theme choice changes.
    final choice = context.select<AppState, String>((a) => a.settings.theme);
    return MaterialApp(
      title: 'Bahi',
      debugShowCheckedModeBanner: false,
      theme: buildBahiTheme(Brightness.light),
      darkTheme: buildBahiTheme(Brightness.dark),
      themeMode: choice == 'light'
          ? ThemeMode.light
          : (choice == 'dark' ? ThemeMode.dark : ThemeMode.system),
      home: const _AppGate(),
    );
  }
}

/// Decides what to show: loading, first-run welcome, PIN lock, or the app.
class _AppGate extends StatefulWidget {
  const _AppGate();
  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  /// Decided once, when the data first loads: locked only if a PIN was already
  /// set at launch. Setting a PIN later in the same session doesn't lock you out.
  bool? _unlocked;

  /// The animated splash always plays through, even if the data loads faster.
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final String stage;
    final Widget page;
    if (!app.loaded || !_splashDone) {
      stage = 'splash';
      page = BahiSplash(
        onFinished: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    } else {
      _unlocked ??= app.settings.pin.isEmpty;
      if (app.settings.bizName.trim().isEmpty) {
        stage = 'welcome';
        page = const _WelcomeScreen();
      } else if (_unlocked == false) {
        stage = 'lock';
        page = _LockScreen(
          pin: app.settings.pin,
          bizName: app.settings.bizName,
          onUnlock: () => setState(() => _unlocked = true),
        );
      } else {
        stage = 'app';
        page = const RootShell();
      }
    }

    // Short cross-fade between splash -> welcome/lock/app.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: KeyedSubtree(key: ValueKey(stage), child: page),
    );
  }
}

// ----------------------------------------------------------------------
// First-run welcome
// ----------------------------------------------------------------------

class _WelcomeScreen extends StatefulWidget {
  const _WelcomeScreen();
  @override
  State<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<_WelcomeScreen> {
  final _biz = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  String _state = '';
  bool _gstReg = true;
  bool _busy = false;

  @override
  void dispose() {
    _biz.dispose();
    _owner.dispose();
    _phone.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _biz.text.trim();
    if (name.isEmpty) {
      toastMsg(context, 'Enter your business name');
      return;
    }
    final g = _gstReg ? _gstin.text.trim().toUpperCase() : '';
    if (g.isNotEmpty && !GSTIN_RE.hasMatch(g)) {
      toastMsg(context, 'GSTIN should be 15 characters, like 27AAPFU0939F1ZV');
      return;
    }
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final s = AppSettings.fromMap(app.settings.toMap())
      ..bizName = name
      ..owner = _owner.text.trim()
      ..phone = _phone.text.trim()
      ..state = _state
      ..gstReg = _gstReg
      ..gstin = g
      ..defType = _gstReg ? 'gst' : 'nongst';
    await app.saveSettings(s);
    // The gate swaps this screen for the app as soon as the name is saved.
  }

  Future<void> _sample() async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    try {
      await app.loadSample();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.receipt_long_rounded, color: c.goldInk, size: 28),
                ),
              ),
              const SizedBox(height: 18),
              Text('Welcome to Bahi',
                  style: GoogleFonts.bricolageGrotesque(fontSize: 30, fontWeight: FontWeight.w800, color: c.ink)),
              const SizedBox(height: 6),
              Text(
                'Bills, stock and deliveries for your shop-to-shop business. Tell us about your business. You can change all of this later in Settings.',
                style: TextStyle(color: c.muted, fontSize: 14.5, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _biz,
                textCapitalization: TextCapitalization.words,
                decoration: bahiInput('Business name'),
              ),
              fieldGap(),
              TextField(
                controller: _owner,
                textCapitalization: TextCapitalization.words,
                decoration: bahiInput('Owner name (optional)'),
              ),
              fieldGap(),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: bahiInput('Phone (optional)'),
              ),
              fieldGap(),
              DropdownButtonFormField<String>(
                key: ValueKey('state-$_state'),
                initialValue: _state.isEmpty ? null : _state,
                isExpanded: true,
                decoration: bahiInput('Your state'),
                items: STATES
                    .map((x) => DropdownMenuItem(
                    value: x[0], child: Text('${x[1]} (${x[0]})', overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _state = v ?? ''),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I am registered under GST'),
                value: _gstReg,
                onChanged: (v) => setState(() => _gstReg = v),
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
                      if (STATES.any((x) => x[0] == code)) setState(() => _state = code);
                    }
                  },
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _start,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Start using Bahi'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _sample, child: const Text('Try it with demo data first')),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// PIN lock
// ----------------------------------------------------------------------

class _LockScreen extends StatefulWidget {
  final String pin;
  final String bizName;
  final VoidCallback onUnlock;
  const _LockScreen({required this.pin, required this.bizName, required this.onUnlock});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  String _entered = '';
  bool _wrong = false;

  void _tap(String d) {
    if (_entered.length >= widget.pin.length) return;
    setState(() {
      _entered += d;
      _wrong = false;
    });
    if (_entered.length == widget.pin.length) {
      if (_entered == widget.pin) {
        widget.onUnlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _entered = '';
          _wrong = true;
        });
      }
    }
  }

  void _back() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.lock_rounded, color: c.goldInk, size: 26),
                ),
                const SizedBox(height: 16),
                Text(widget.bizName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
                const SizedBox(height: 4),
                Text(_wrong ? 'Wrong PIN, try again' : 'Enter your PIN',
                    style: TextStyle(color: _wrong ? c.red : c.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.pin.length, (i) {
                    final on = i < _entered.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? c.blue : Colors.transparent,
                        border: Border.all(color: _wrong ? c.red : (on ? c.blue : c.muted), width: 1.6),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: row.map((d) => _key(context, label: d, onTap: () => _tap(d))).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 84),
                      _key(context, label: '0', onTap: () => _tap('0')),
                      _key(context, icon: Icons.backspace_outlined, onTap: _back),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _key(BuildContext context, {String? label, IconData? icon, required VoidCallback onTap}) {
    final c = context.bahi;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: label != null ? c.card : Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: label != null ? c.line : Colors.transparent)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: label != null
                  ? Text(label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: c.ink))
                  : Icon(icon, color: c.muted),
            ),
          ),
        ),
      ),
    );
  }
}