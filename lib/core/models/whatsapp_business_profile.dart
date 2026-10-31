/// Perfil de WhatsApp Business del número que usa el usuario (datos reales de Meta)
class WhatsappBusinessProfile {
  final String nombre;
  final String telefono;
  final bool esPrueba;
  final bool editable;
  final String about;
  final String address;
  final String description;
  final String email;
  final String? foto;
  final List<String> websites;
  final String? vertical;
  final List<Map<String, String>> categorias;

  const WhatsappBusinessProfile({
    required this.nombre,
    required this.telefono,
    required this.esPrueba,
    required this.editable,
    required this.about,
    required this.address,
    required this.description,
    required this.email,
    this.foto,
    this.websites = const [],
    this.vertical,
    this.categorias = const [],
  });

  factory WhatsappBusinessProfile.fromJson(Map<String, dynamic> j) {
    String s(dynamic v) => v?.toString() ?? '';
    return WhatsappBusinessProfile(
      nombre: s(j['nombre']),
      telefono: s(j['telefono']),
      esPrueba: j['es_prueba'] == true,
      editable: j['editable'] == true,
      about: s(j['about']),
      address: s(j['address']),
      description: s(j['description']),
      email: s(j['email']),
      foto: (j['foto'] == null || s(j['foto']).isEmpty) ? null : s(j['foto']),
      websites: ((j['websites'] as List?) ?? const []).map((e) => e.toString()).toList(),
      vertical: j['vertical']?.toString(),
      categorias: ((j['categorias'] as List?) ?? const [])
          .map((e) => {'id': e['id'].toString(), 'nombre': e['nombre'].toString()})
          .toList(),
    );
  }

  String get categoriaNombre {
    for (final c in categorias) {
      if (c['id'] == vertical) return c['nombre']!;
    }
    return '';
  }
}
