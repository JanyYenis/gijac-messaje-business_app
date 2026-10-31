import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/paises_telefono.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/api_service.dart';
import '../../widgets/app_avatar.dart';

/// Editar nombre, apellido, teléfono y la foto de perfil (la misma que se ve en la web).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _telefono;
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  bool _subiendoFoto = false;
  final _identificacion = TextEditingController();
  Map<String, List<Map<String, String>>>? _opciones;
  List<Map<String, String>> _ciudades = [];
  String? _generoId, _tipoDocId, _paisId, _ciudadId;
  bool _cargandoCiudades = false;
  String? _errorOpciones;
  late PaisTelefono _pais;
  late final bool _indicativoConMas; // se respeta el formato con que ya está guardado ("57" o "+57")

  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider).user;
    _nombre = TextEditingController(text: u?.nombre ?? '');
    _apellido = TextEditingController(text: u?.apellido ?? '');
    _telefono = TextEditingController(text: u?.telefono ?? '');
    _pais = PaisTelefono.porIndicativo(u?.codigoTelefono) ?? PaisTelefono.colombia;
    _indicativoConMas = (u?.codigoTelefono ?? '').startsWith('+');
    _identificacion.text = u?.identificacion ?? '';
    _generoId = u?.generoId;
    _tipoDocId = u?.tipoIdentificacion;
    _paisId = u?.paisId;
    _ciudadId = u?.codCiudad;
    _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    try {
      final o = await ApiService().getOpcionesPerfil();
      if (!mounted) return;
      setState(() {
        _opciones = o;
        _errorOpciones = null;
        // Un valor guardado que ya no existe en la lista se descarta para no romper el desplegable
        if (!o['generos']!.any((e) => e['id'] == _generoId)) _generoId = null;
        if (!o['documentos']!.any((e) => e['id'] == _tipoDocId)) _tipoDocId = null;
        if (!o['paises']!.any((e) => e['id'] == _paisId)) _paisId = null;
      });
      if (_paisId != null) await _cargarCiudades(_paisId!, conservar: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorOpciones = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorOpciones = 'No se pudieron cargar las opciones.');
    }
  }

  Future<void> _cargarCiudades(String paisId, {bool conservar = false}) async {
    setState(() {
      _cargandoCiudades = true;
      if (!conservar) _ciudadId = null;
    });
    try {
      final c = await ApiService().getCiudades(paisId);
      if (!mounted) return;
      setState(() {
        _ciudades = c;
        if (!c.any((e) => e['id'] == _ciudadId)) _ciudadId = null;
      });
    } catch (_) {
      _aviso('No se pudieron cargar las ciudades.');
    } finally {
      if (mounted) setState(() => _cargandoCiudades = false);
    }
  }

  /// Hoja con buscador para países y ciudades (las listas pueden ser largas)
  Future<String?> _elegirDeLista(String titulo, List<Map<String, String>> items, String? actual) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectorLista(titulo: titulo, items: items, actual: actual),
    );
  }

  String _nombreDe(List<Map<String, String>>? items, String? id) {
    if (items == null || id == null) return '';
    for (final e in items) {
      if (e['id'] == id) return e['nombre']!;
    }
    return '';
  }

  Widget _campoSelector({required String label, required String valor, required VoidCallback? onTap, bool cargando = false}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: cargando
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(valor.isEmpty ? ' ' : valor, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _telefono.dispose();
    _identificacion.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _guardar() async {
    if (_opciones == null) {
      _aviso('Espera a que carguen las opciones del formulario.');
      return;
    }
    final formOk = _formKey.currentState!.validate();
    if (_paisId == null || _ciudadId == null) {
      _aviso('Selecciona el país y la ciudad.');
      return;
    }
    if (!formOk || _guardando) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final perfil = await ApiService().updateProfile({
        'nombre': _nombre.text.trim(),
        'apellido': _apellido.text.trim(),
        'genero': _generoId,
        'tipo_identificacion': _tipoDocId,
        'identificacion': _identificacion.text.trim(),
        'telefono': _telefono.text.trim(),
        'codigo_telefono': '${_indicativoConMas ? '+' : ''}${_pais.dial}',
        'pais_id': _paisId,
        'cod_ciudad': _ciudadId,
      });
      await ref.read(userProvider.notifier).setUser(perfil);
      _aviso('Perfil actualizado');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _aviso(e.message);
    } catch (_) {
      _aviso('No se pudo guardar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirPais() async {
    final elegido = await showModalBottomSheet<PaisTelefono>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectorPais(actual: _pais),
    );
    if (elegido != null) setState(() => _pais = elegido);
  }

  Future<void> _cambiarFoto() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (fuente == null) return;

    try {
      // Se reduce antes de subir: el servidor acepta hasta 2 MB
      final x = await ImagePicker().pickImage(source: fuente, imageQuality: 80, maxWidth: 1024, maxHeight: 1024);
      if (x == null) return;
      setState(() => _subiendoFoto = true);
      final perfil = await ApiService().uploadProfilePhoto(File(x.path));
      await ref.read(userProvider.notifier).setUser(perfil);
      _aviso('Foto actualizada');
    } on ApiException catch (e) {
      _aviso(e.message);
    } catch (e) {
      _aviso('No se pudo cambiar la foto.');
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(userProvider).user;
    final partes = (user?.nombreCompleto ?? '').split(' ').where((s) => s.isNotEmpty).take(2).toList();
    final iniciales = partes.isEmpty ? 'U' : partes.map((s) => s[0].toUpperCase()).join();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
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
                      AppAvatar(initials: iniciales, radius: 56, colorValue: 0xFF3B82F6, imageUrl: user?.foto),
                      if (_subiendoFoto)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(Icons.photo_camera, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _subiendoFoto ? null : _cambiarFoto,
                  child: const Text('Cambiar foto'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder(), counterText: ''),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _apellido,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Apellido', border: OutlineInputBorder(), counterText: ''),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu apellido' : null,
              ),
              const SizedBox(height: 14),
              if (_errorOpciones != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Expanded(child: Text(_errorOpciones!, style: TextStyle(color: theme.colorScheme.error))),
                    TextButton(onPressed: _cargarOpciones, child: const Text('Reintentar')),
                  ]),
                ),
              DropdownButtonFormField<String>(
                value: _generoId,
                decoration: const InputDecoration(labelText: 'Género', border: OutlineInputBorder()),
                items: (_opciones?['generos'] ?? []).map((e) => DropdownMenuItem(value: e['id'], child: Text(e['nombre']!))).toList(),
                onChanged: _opciones == null ? null : (v) => setState(() => _generoId = v),
                validator: (v) => v == null ? 'Selecciona el género' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _tipoDocId,
                decoration: const InputDecoration(labelText: 'Tipo de identificación', border: OutlineInputBorder()),
                items: (_opciones?['documentos'] ?? []).map((e) => DropdownMenuItem(value: e['id'], child: Text(e['nombre']!))).toList(),
                onChanged: _opciones == null ? null : (v) => setState(() => _tipoDocId = v),
                validator: (v) => v == null ? 'Selecciona el tipo de identificación' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _identificacion,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Número de identificación', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu número de identificación' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _elegirPais,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_pais.bandera, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 6),
                          Text('+${_pais.dial}'),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)],
                      decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Escribe tu teléfono';
                        if (t.length < 6) return 'Número demasiado corto';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _campoSelector(
                label: 'País',
                valor: _nombreDe(_opciones?['paises'], _paisId),
                onTap: _opciones == null
                    ? null
                    : () async {
                        final id = await _elegirDeLista('País', _opciones!['paises']!, _paisId);
                        if (id != null && id != _paisId) {
                          setState(() => _paisId = id);
                          await _cargarCiudades(id);
                        }
                      },
              ),
              const SizedBox(height: 14),
              _campoSelector(
                label: 'Ciudad',
                valor: _nombreDe(_ciudades, _ciudadId),
                cargando: _cargandoCiudades,
                onTap: (_paisId == null || _cargandoCiudades)
                    ? null
                    : () async {
                        final id = await _elegirDeLista('Ciudad', _ciudades, _ciudadId);
                        if (id != null) setState(() => _ciudadId = id);
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: user?.email ?? '',
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                  helperText: 'El correo y la contraseña se cambian desde la web.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con buscador para elegir el país del indicativo
class _SelectorPais extends StatefulWidget {
  const _SelectorPais({required this.actual});

  final PaisTelefono actual;

  @override
  State<_SelectorPais> createState() => _SelectorPaisState();
}

class _SelectorPaisState extends State<_SelectorPais> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase().replaceAll('+', '');
    final paises = q.isEmpty
        ? PaisTelefono.lista
        : PaisTelefono.lista.where((p) => p.nombre.toLowerCase().contains(q) || p.dial.startsWith(q) || p.iso.toLowerCase() == q).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar país o indicativo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: paises.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.builder(
                      itemCount: paises.length,
                      itemBuilder: (_, i) {
                        final p = paises[i];
                        final seleccionado = p.iso == widget.actual.iso;
                        return ListTile(
                          leading: Text(p.bandera, style: const TextStyle(fontSize: 24)),
                          title: Text(p.nombre),
                          trailing: Text('+${p.dial}', style: Theme.of(context).textTheme.bodyMedium),
                          selected: seleccionado,
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior con buscador para elegir de una lista (país, ciudad)
class _SelectorLista extends StatefulWidget {
  const _SelectorLista({required this.titulo, required this.items, required this.actual});

  final String titulo;
  final List<Map<String, String>> items;
  final String? actual;

  @override
  State<_SelectorLista> createState() => _SelectorListaState();
}

class _SelectorListaState extends State<_SelectorLista> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final lista = q.isEmpty ? widget.items : widget.items.where((e) => e['nombre']!.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar ${widget.titulo.toLowerCase()}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(lista[i]['nombre']!),
                        selected: lista[i]['id'] == widget.actual,
                        onTap: () => Navigator.pop(context, lista[i]['id']),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}