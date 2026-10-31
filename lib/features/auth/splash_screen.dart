import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/services/cache_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final CacheService _cacheService = CacheService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Esperar un momento para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));

    // Verificar si hay datos guardados
    final hasData = await _cacheService.hasDeviceData();

    if (!mounted) return;

    if (hasData) {
      // Ya hay token y servidor, ir al dashboard
      appRouter.go(Routes.dashboard);
    } else {
      // No hay datos, ir a escanear QR
      appRouter.go(Routes.qrLogin);
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54), // Fondo verde oscuro
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO CON FONDO VERDE
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366), // Fondo verde claro
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20), // Espacio interno para el logo
              child: Image.asset(
                'assets/images/logo_gmb_blanco.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'GIJAC',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'MESSAGE BUSINESS',
              style: TextStyle(
                color: Color(0xFF25D366),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFF25D366),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}