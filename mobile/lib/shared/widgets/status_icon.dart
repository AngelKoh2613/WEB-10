import 'package:flutter/material.dart';

class StatusIcon extends StatelessWidget {
  const StatusIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 30, color: color),
    );
  }
}
