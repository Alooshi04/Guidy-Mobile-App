import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// "Ask the driver: going to Cine Plex?": what to say when waving a road
/// vehicle down, in place of a list of lines the rider can't tell apart.
class AskDriverText extends StatelessWidget {
  const AskDriverText(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.record_voice_over_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary, height: 1.25)),
          ),
        ]),
      );
}

/// The small "Which microbuses?" row that opens the lines a leg could be.
class LinesToggle extends StatelessWidget {
  const LinesToggle({super.key, required this.label, required this.open, required this.onTap});

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
            Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: context.textSecondary),
          ]),
        ),
      );
}
