import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';

class DeviceValidationScreen extends StatefulWidget {
  const DeviceValidationScreen({super.key});

  @override
  State<DeviceValidationScreen> createState() => _DeviceValidationScreenState();
}

class _DeviceValidationScreenState extends State<DeviceValidationScreen> {
  int _step = 0; // 0 = validating, 1 = success
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _step = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: Responsive.horizontalPadding(context)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _step == 0 ? _validating(theme) : _success(theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _validating(ThemeData theme) {
    return Column(
      key: const ValueKey('validating'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
        const SizedBox(height: 28),
        Text('Validando dispositivo',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Estamos verificando la seguridad de la conexión y sincronizando tu cuenta.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 24),
        _checklist(theme),
      ],
    );
  }

  Widget _checklist(ThemeData theme) {
    final items = const [
      'Conexión cifrada de extremo a extremo',
      'Verificando credenciales del dispositivo',
      'Sincronizando conversaciones',
    ];
    return Column(
      children: items
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 18, color: AppColors.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text(e, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _success(ThemeData theme) {
    // Auto-continue once validated.
    if (!_navigated) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) context.go(Routes.dashboard);
      });
    }
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: AppColors.primary, size: 56),
        ),
        const SizedBox(height: 28),
        Text('Dispositivo verificado',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Tu cuenta de WhatsApp Business se ha vinculado correctamente.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.go(Routes.dashboard),
          child: const Text('Ir al panel'),
        ),
      ],
    );
  }
}
