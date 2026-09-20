import 'package:flutter/material.dart';
import '../../theme.dart';

class StatusChip extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? fg;
  const StatusChip(this.text, {super.key, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? c.line,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg ?? c.muted,
          height: 1.3,
        ),
      ),
    );
  }

  static StatusChip blue(BuildContext ctx, String t) =>
      StatusChip(t, bg: ctx.bahi.blueSoft, fg: ctx.bahi.blue);
  static StatusChip green(BuildContext ctx, String t) =>
      StatusChip(t, bg: ctx.bahi.greenSoft, fg: ctx.bahi.green);
  static StatusChip gold(BuildContext ctx, String t) =>
      StatusChip(t, bg: ctx.bahi.goldSoft, fg: ctx.bahi.gold);
  static StatusChip red(BuildContext ctx, String t) =>
      StatusChip(t, bg: ctx.bahi.redSoft, fg: ctx.bahi.red);
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? action;
  const EmptyState(this.title, {super.key, this.sub, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.ink)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 13.5)),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: c.ink)),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: Text(actionLabel!,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: c.blue)),
            ),
        ],
      ),
    );
  }
}

class CardList extends StatelessWidget {
  final List<Widget> children;
  const CardList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class LiRow extends StatelessWidget {
  final Widget mainTop;
  final Widget? mainBottom;
  final Widget? end;
  final VoidCallback? onTap;
  final bool dim;
  const LiRow({super.key, required this.mainTop, this.mainBottom, this.end, this.onTap, this.dim = false});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    mainTop,
                    if (mainBottom != null) ...[const SizedBox(height: 2), mainBottom!],
                  ],
                ),
              ),
              if (end != null) ...[const SizedBox(width: 12), end!],
            ],
          ),
        ),
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const KpiCard({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12.5, color: c.muted)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? c.ink)),
          ],
        ),
      ),
    );
  }
}

class Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const Tile({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.bahi;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.blueSoft, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: c.blue, size: 19),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
          ],
        ),
      ),
    );
  }
}

Widget fieldGap() => const SizedBox(height: 10);

InputDecoration bahiInput(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
);