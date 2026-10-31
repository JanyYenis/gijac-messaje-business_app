import 'package:flutter/material.dart';

/// Circular avatar with colored initials and optional online dot.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    this.colorValue = 0xFF25D366,
    this.radius = 24,
    this.isOnline = false,
    this.imageUrl,
  });

  final String initials;
  final int colorValue;
  final double radius;
  final bool isOnline;

  /// Foto de perfil (URL). Si falta o no carga, se muestran las iniciales.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final iniciales = Text(
      initials,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.7,
      ),
    );
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: color.withValues(alpha: 0.15),
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? iniciales
              : ClipOval(
                  child: Image.network(
                    imageUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    cacheWidth: (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
                    errorBuilder: (_, __, ___) => iniciales,
                  ),
                ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}