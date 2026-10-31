import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/brand_logo.dart';

class QrLoginScreen extends StatelessWidget {
  const QrLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = const [
      'Abre WhatsApp Business en tu teléfono.',
      'Toca Menú o Configuración y selecciona Dispositivos vinculados.',
      'Apunta tu teléfono hacia esta pantalla para escanear el código.',
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context),
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  const BrandLogo(size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Vincular dispositivo',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inicia sesión escaneando el código QR con WhatsApp Business.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _QrPlaceholder(),
                  const SizedBox(height: 28),
                  ...List.generate(steps.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(steps[i],
                                style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push(Routes.qrScanner),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear código QR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.qr_code_2,
                size: 200,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85)),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.surface, width: 3),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: Colors.white, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}