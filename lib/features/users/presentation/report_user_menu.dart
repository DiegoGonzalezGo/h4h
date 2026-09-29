import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';

class ReportUserMenu extends ConsumerWidget {
  final String reportedUserId;

  const ReportUserMenu({super.key, required this.reportedUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'report') {
          _showReportReasons(context, ref, reportedUserId);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Reportar usuario'),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showReportReasons(
  BuildContext context,
  WidgetRef ref,
  String reportedUserId,
) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              '¿Por qué deseas reportar a este usuario?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sentiment_dissatisfied_outlined),
            title: const Text('Comportamiento ofensivo'),
            onTap: () =>
                Navigator.of(sheetContext).pop('Comportamiento ofensivo'),
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('Fraude o perfil falso'),
            onTap: () =>
                Navigator.of(sheetContext).pop('Fraude o perfil falso'),
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Spam'),
            onTap: () => Navigator.of(sheetContext).pop('Spam'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (reason == null || !context.mounted) return;

  try {
    await ref.read(userRepositoryProvider).reportUser(reportedUserId, reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gracias, hemos recibido tu reporte y lo revisaremos'),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo enviar el reporte: $error')),
    );
  }
}
