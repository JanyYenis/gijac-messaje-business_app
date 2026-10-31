import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/whatsapp_business_profile.dart';
import '../../core/services/api_service.dart';
import '../../widgets/app_avatar.dart';

/// Editar el perfil de WhatsApp Business (solo números de producción). Mismos campos que la web.
class EditWhatsappProfileScreen extends StatefulWidget {
  const EditWhatsappProfileScreen({super.key, required this.perfil});

  final WhatsappBusinessProfile perfil;

  @override
  State<EditWhatsappProfileScreen> createState() => _EditWhatsappProfileScreenState();
}

class _EditWhatsappProfileScreenState extends State<EditWhatsappProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _about;
  late final TextEditingController _email;
  late final TextEditingController _descripcion;
  late final TextEditingController _direccion;
  late final TextEditingController _web1;
  late final TextEditingController _web2;
  String? _vertical;
  bool _guardando = false;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    final p = widget.perfil;
    _about = TextEditingController(text: p.about);
    _email = TextEditingController(text: p.email);
    _descripcion = TextEditingController(text: p.description);
    _direccion = TextEditingController(text: p.address);
    _web1 = TextEditingController(text: p.websites.isNotEmpty ? p.websites[0] : '');
    _web2 = TextEditingController(text: p.websites.length > 1 ? p.websites[1] : '');
    _vertical = p.categorias.any((c) => c['id'] == p.vertical) ? p.vertical : null;
  }

  @override
  void dispose() {
    for (final c in [_about, _email, _descripcion, _direccion, _web1, _web2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _aviso(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  String? _validarWeb(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final u = Uri.tryParse(t);
    return (u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty) ? null : 'Debe empezar por https://';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _guardando) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final nuevo = await ApiService().updateWhatsappProfile({
        'about': _about.text.trim(),
        'email': _email.text.trim(),
        'vertical': _vertical,
        'description': _descripcion.text.trim(),
        'address': _direccion.text.trim(),
        'websites': [_web1.text.trim(), _web2.text.trim()].where((e) => e.isNotEmpty).toList(),
      });
      _aviso('Perfil de WhatsApp actualizado');
      if (mounted) Navigator.of(context).pop(nuevo);
    } on ApiException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('No se pudo guardar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarFoto() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Tomar foto'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de la galería'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (fuente == null) return;
    try {
      final x = await ImagePicker().pickImage(source: fuente, imageQuality: 85, maxWidth: 1024, maxHeight: 1024);
      if (x == null) return;
      setState(() => _subiendoFoto = true);
      _aviso(await ApiService().uploadWhatsappPhoto(File(x.path)));
    } on ApiException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('No se pudo subir la foto.');
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;
    final partes = p.nombre.split(' ').where((s) => s.isNotEmpty).take(2).toList();
    final iniciales = partes.isEmpty ? 'WB' : partes.map((s) => s[0].toUpperCase()).join();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil de WhatsApp'),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _subiendoFoto ? null : _cambiarFoto,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AppAvatar(initials: iniciales, radius: 56, colorValue: 0xFF128C7E, imageUrl: p.foto),
                      if (_subiendoFoto)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                            child: Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Center(child: TextButton(onPressed: _subiendoFoto ? null : _cambiarFoto, child: const Text('Cambiar foto'))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _about,
                maxLength: 139,
                decoration: const InputDecoration(labelText: 'Info', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'La info es requerida' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'El email es requerido';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Email no válido';
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _vertical,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                items: p.categorias.map((c) => DropdownMenuItem(value: c['id'], child: Text(c['nombre']!))).toList(),
                onChanged: (v) => setState(() => _vertical = v),
                validator: (v) => v == null ? 'Selecciona la categoría' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descripcion,
                maxLength: 512,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _direccion,
                maxLength: 256,
                decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _web1,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Sitio web 1', hintText: 'https://www.ejemplo.com', border: OutlineInputBorder()),
                validator: _validarWeb,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _web2,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Sitio web 2 (opcional)', hintText: 'https://www.ejemplo.com', border: OutlineInputBorder()),
                validator: _validarWeb,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
