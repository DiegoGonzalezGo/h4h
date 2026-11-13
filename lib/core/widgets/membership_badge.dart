import 'package:flutter/material.dart';

class MembershipBadge extends StatelessWidget {
  const MembershipBadge({required this.isElite, super.key});

  final bool isElite;

  @override
  Widget build(BuildContext context) {
    final color = isElite ? const Color(0xFFFFC107) : Colors.cyanAccent;
    final label = isElite ? 'ÉLITE' : 'PRO';
    final icon = isElite ? Icons.workspace_premium : Icons.verified_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: isElite ? 10 : 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
