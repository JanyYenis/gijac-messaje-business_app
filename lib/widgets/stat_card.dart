import 'package:flutter/material.dart';

/// Statistic card with icon, value, label and optional trend.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.trend,
    this.trendUp = true,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? trend;
  final bool trendUp;

    @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12), // Reducido de 16 a 12
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8), // Reducido de 10 a 8
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20), // Reducido de 22 a 20
              ),
              if (trend != null)
                Row(
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up : Icons.trending_down,
                      size: 14, // Reducido de 16 a 14
                      color: trendUp
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend!,
                      maxLines: 1, // AGREGADO
                      overflow: TextOverflow.ellipsis, // AGREGADO
                      style: TextStyle(
                        fontSize: 11, // Reducido de 12 a 11
                        fontWeight: FontWeight.w600,
                        color: trendUp
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8), // Reducido de 14 a 8
          Text(
            value,
            maxLines: 1, // AGREGADO
            overflow: TextOverflow.ellipsis, // AGREGADO
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1, // AGREGADO
            overflow: TextOverflow.ellipsis, // AGREGADO
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
