import 'package:flutter/material.dart';

import '../core/services/biometria_service.dart';

/// Envuelve toda la app:
///  - deja espacio para la barra de navegación/gestos del teléfono (que no tape el contenido)
///  - aplica el bloqueo biométrico al abrir y al volver tras un rato en segundo plano
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  static const _gracia = Duration(seconds: 30); // cámara/galería/permisos no deben bloquear al volver
  bool _bloqueado = false;
  bool _verificando = false;
  DateTime? _salida;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloquearSiActivo(); // al abrir la app
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bloquearSiActivo() async {
    if (await BiometriaService.activo() && mounted) {
      setState(() => _bloqueado = true);
      _pedir();
    }
  }

  Future<void> _pedir() async {
    if (_verificando) return;
    _verificando = true;
    final ok = await BiometriaService.autenticar('Desbloquea GIJAC');
    _verificando = false;
    if (ok && mounted) setState(() => _bloqueado = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_verificando) return; // el propio diálogo del sistema pausa la app
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _salida ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final salida = _salida;
      _salida = null;
      if (salida != null && DateTime.now().difference(salida) > _gracia) _bloquearSiActivo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fondo = Theme.of(context).scaffoldBackgroundColor;
    // SafeArea abajo: la barra del sistema (Android 15 dibuja la app detrás) y el indicador de inicio de iPhone.
    // Arriba no: cada pantalla ya maneja la barra de estado con su AppBar.
    final contenido = ColoredBox(
      color: fondo,
      child: SafeArea(top: false, child: widget.child),
    );
    if (!_bloqueado) return contenido;

    final tema = Theme.of(context);
    return Stack(
      children: [
        contenido,
        Positioned.fill(
          child: Material(
            color: fondo,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: tema.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('GIJAC bloqueada', style: tema.textTheme.titleLarge),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _pedir,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
