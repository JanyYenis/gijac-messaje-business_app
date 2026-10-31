import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/biometria_service.dart';
import '../../widgets/section_card.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _urlPerfil = 'https://message-business.gijac.com/perfil';

  bool _biometria = false;
  bool _disponible = true;
  bool _cambiando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final activo = await BiometriaService.activo();
    final disp = await BiometriaService.disponible();
    if (mounted) {
      setState(() {
        _biometria = activo;
        _disponible = disp;
      });
    }
  }

  void _aviso(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _cambiarBiometria(bool v) async {
    if (_cambiando) return;
    setState(() => _cambiando = true);
    final estado = await BiometriaService.cambiar(v);
    if (!mounted) return;
    setState(() {
      _biometria = estado;
      _cambiando = false;
    });
    if (v && !estado) {
      _aviso(_disponible
          ? 'No se pudo activar el bloqueo.'
          : 'Configura una huella, rostro o bloqueo de pantalla en los ajustes del teléfono.');
    }
  }

  Future<void> _abrirWeb() async {
    final ok = await launchUrl(Uri.parse(_urlPerfil), mode: LaunchMode.externalApplication);
    if (!ok) _aviso('No se pudo abrir la página.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Autenticación'),
          GroupedCard(children: [
            AppTile(
              icon: Icons.password,
              title: 'Cambiar contraseña',
              subtitle: 'Se cambia desde la web',
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: _abrirWeb,
            ),
            AppTile(
              icon: Icons.fingerprint,
              title: 'Bloqueo biométrico',
              subtitle: _disponible ? 'Huella o rostro al abrir la app' : 'No hay huella, rostro ni bloqueo de pantalla configurado',
              trailing: Switch(value: _biometria, onChanged: _cambiando ? null : _cambiarBiometria),
            ),
          ]),
        ],
      ),
    );
  }
}