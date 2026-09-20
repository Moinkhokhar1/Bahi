import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../theme.dart';

/// Shows a signature-capture bottom sheet. Returns a base64-encoded PNG
/// string on save, `''` if the user tapped "skip" (when [skipLabel] is
/// given), or `null` if dismissed / cancelled.
Future<String?> showSignatureSheet(
    BuildContext context, {
      required String title,
      String? subtitle,
      String okLabel = 'Save signature',
      String? skipLabel,
      bool nameField = false,
      String nameLabel = 'Name',
      String nameInitial = '',
      required void Function(String name)? onName,
    }) async {
  final controller = SignatureController(penColor: const Color(0xFF13215A), penStrokeWidth: 2.6);
  final nameCtrl = TextEditingController(text: nameInitial);
  String? result;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.bahi;
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: c.muted, fontSize: 13.5)),
              ],
              if (nameField) ...[
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: nameLabel)),
              ],
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: c.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Signature(controller: controller, backgroundColor: Colors.transparent),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.clear(),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (controller.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please sign in the box first')));
                          return;
                        }
                        final bytes = await controller.toPngBytes();
                        if (bytes != null) result = base64Encode(bytes);
                        if (onName != null) onName(nameCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(okLabel),
                    ),
                  ),
                ],
              ),
              if (skipLabel != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    result = '';
                    if (onName != null) onName(nameCtrl.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: Text(skipLabel),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  return result;
}