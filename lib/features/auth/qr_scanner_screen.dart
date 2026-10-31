import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';

import '../../core/services/cache_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_events.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/router/app_router.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final CacheService _cacheService = CacheService();
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  void _onQRDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    _processQRData(code);
  }

    Future<void> _processQRData(String rawData) async {
    try {
      final uri = Uri.parse(rawData);

      String? token;
      String? server;

      if (uri.scheme == 'gijac') {
        token = uri.queryParameters['token'];
        server = uri.queryParameters['server'];
      } else if (uri.scheme == 'http' || uri.scheme == 'https') {
        token = uri.queryParameters['token'];
        server = uri.queryParameters['server'];
      } else {
        try {
          final json = jsonDecode(rawData);
          token = json['token'];
          server = json['server'];
        } catch (_) {}
      }

      if (token != null && server != null) {
        // 1. Guardar servidor temporalmente
        await _cacheService.saveServerUrl(server);
         await _cacheService.saveServerUrl(server);

        // 2. Liberar la cámara: ya se leyó el código (evita que siga generando cuadros mientras se registra)
        try {
          await cameraController.stop();
        } catch (_) {}

        // 3. Obtener info del celular
        final deviceInfoPlugin = DeviceInfoPlugin();
        Map<String, dynamic> deviceData = {
          'nombre_dispositivo': 'Desconocido',
          'modelo': null,
          'sistema_operativo': 'Desconocido',
          'version_so': null,
          'fcm_token': null,
        };

        bool registrado = false;
        try {
          if (Platform.isAndroid) {
            final android = await deviceInfoPlugin.androidInfo;
            deviceData = {
              'token': token,
              'nombre_dispositivo': android.model ?? 'Android',
              'modelo': android.model,
              'sistema_operativo': 'Android',
              'version_so': android.version.release,
              'fcm_token': null,
              'ip': null,
            };
          } else if (Platform.isIOS) {
            final ios = await deviceInfoPlugin.iosInfo;
            deviceData = {
              'token': token,
              'nombre_dispositivo': ios.name ?? 'iPhone',
              'modelo': ios.model,
              'sistema_operativo': 'iOS',
              'version_so': ios.systemVersion,
              'fcm_token': null,
              'ip': null,
            };
          }

          try {
            deviceData['fcm_token'] = await FirebaseMessaging.instance.getToken();
          } catch (e) {
            debugPrint('⚠️ No se pudo obtener el token FCM: $e');
          }

          // 4. Enviar a Laravel (reintenta: justo después de instalar, la red puede tardar en estabilizarse)
          for (var i = 0; i < 3 && !registrado; i++) {
            registrado = await ApiService().registerDevice(deviceData);
            if (!registrado && i < 2) await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          debugPrint('⚠️ Error al registrar dispositivo: $e');
        }

        if (!registrado) {
          _showError('No se pudo vincular el dispositivo. Revisa tu conexión e inténtalo de nuevo.');
          try {
            await cameraController.start();
          } catch (_) {}
          return;
        }

        // 5. Guardar el token
        await _cacheService.saveDeviceToken(token);

        // Guardar el perfil en caché (ya con sesión); si falla, el panel lo cargará después
        try {
          await UserRepository(ApiService(), _cacheService).getProfile().timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('⚠️ Perfil no cargado tras escanear: $e');
        }

        // Con la sesión ya guardada: pide el permiso de notificaciones y conecta el tiempo real sin reiniciar la app
        SessionEvents.onLogin?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dispositivo vinculado exitosamente'),
              backgroundColor: Color(0xFF25D366),
              behavior: SnackBarBehavior.floating,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          appRouter.go('/dashboard');
        }
      } else {
        _showError('Código QR no válido');
      }
    } catch (e) {
      _showError('Error al procesar el QR');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onQRDetected,
          ),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF25D366),
                  width: 3,
                ),
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF25D366)),
              ),
            ),

          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: const Text(
              'Apunta la cámara al código QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}