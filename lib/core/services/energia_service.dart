import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/app_router.dart';

/// Android: pide una sola vez que la app funcione "sin restricciones" de batería y, en Oppo/Realme/OnePlus,
/// abre la pantalla de "Inicio automático". Sin esto ColorOS cierra la app y deja de entregar los push.
/// iPhone no lo necesita (los push llegan por APNs).
class EnergiaService {
  EnergiaService._();

  static const _canal = MethodChannel('gijac/energia');
  static const _kAvisado = 'energia_aviso_mostrado';
  static const _marcasConInicioAutomatico = ['oppo', 'realme', 'oneplus'];

  static Future<void> avisarUnaVez() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAvisado) == true) return;

      final libre = await _canal.invokeMethod<bool>('bateriaSinRestriccion') ?? false;
      final marca = ((await _canal.invokeMethod<String>('fabricante')) ?? '').toLowerCase();
      final pideInicio = _marcasConInicioAutomatico.contains(marca);

      if (libre && !pideInicio) {
        await prefs.setBool(_kAvisado, true);
        return;
      }

      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.mounted) return; // se reintenta en el próximo inicio
      await prefs.setBool(_kAvisado, true);

      final acepta = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Recibe tus mensajes siempre'),
          content: Text(
            pideInicio
                ? 'Para que lleguen las notificaciones con la app cerrada, permite que GIJAC funcione sin restricciones '
                    'y actívala en "Inicio automático". Te llevaremos a cada pantalla.'
                : 'Para que lleguen las notificaciones con la app cerrada, permite que GIJAC funcione sin restricciones de batería.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ahora no')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Configurar')),
          ],
        ),
      );
      if (acepta != true) return;

      if (!libre) {
        await _irYVolver(() => _canal.invokeMethod('pedirSinRestriccion'));
      }
      if (pideInicio) {
        await _canal.invokeMethod('abrirInicioAutomatico');
      }
    } catch (e) {
      debugPrint('⚠️ Energía: no se pudo mostrar el aviso: $e');
    }
  }

  /// Lanza una pantalla del sistema y espera a que el usuario vuelva a la app (máx. 60 s)
  static Future<void> _irYVolver(Future<void> Function() abrir) async {
    final vuelta = Completer<void>();
    var salio = false;
    final escucha = AppLifecycleListener(
      onInactive: () => salio = true,
      onPause: () => salio = true,
      onResume: () {
        if (salio && !vuelta.isCompleted) vuelta.complete();
      },
    );
    try {
      await abrir();
      await vuelta.future.timeout(const Duration(seconds: 60), onTimeout: () {});
    } finally {
      escucha.dispose();
    }
  }
}
