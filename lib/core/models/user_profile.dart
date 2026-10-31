class UserProfile {
  final String id;
  final String nombre;
  final String? apellido;
  final String nombreCompleto;
  final String email;
  final String? telefono;
  final String? codigoTelefono;
  final String? numeroCompleto;
  final String? foto;
  final String? tipoIdentificacion;
  final String? identificacion;
  final String? generoId;
  final String? paisId;
  final String? codCiudad;
  final GeneroInfo? genero;
  final CiudadInfo? ciudad;
  final EmpresaInfo? empresa;
  final PlanInfo? plan;
  final List<String> roles;
  final bool tiene2fa;
  final bool verificado;
  final String? phoneNumberId;

  const UserProfile({
    required this.id,
    required this.nombre,
    this.apellido,
    required this.nombreCompleto,
    required this.email,
    this.telefono,
    this.codigoTelefono,
    this.numeroCompleto,
    this.foto,
    this.tipoIdentificacion,
    this.identificacion,
    this.generoId,
    this.paisId,
    this.codCiudad,
    this.genero,
    this.ciudad,
    this.empresa,
    this.plan,
    this.roles = const [],
    this.tiene2fa = false,
    this.verificado = false,
    this.phoneNumberId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) => v?.toString();
    return UserProfile(
      id: str(json['id']) ?? '',
      nombre: str(json['nombre']) ?? '',
      apellido: str(json['apellido']),
      nombreCompleto: str(json['nombre_completo']) ?? '',
      email: str(json['email']) ?? '',
      telefono: str(json['telefono']),
      codigoTelefono: str(json['codigo_telefono']),
      numeroCompleto: str(json['numero_completo']),
      foto: str(json['foto']),
      tipoIdentificacion: str(json['tipo_identificacion']),
      identificacion: str(json['identificacion']),
      generoId: str(json['genero_id']),
      paisId: str(json['pais_id']),
      codCiudad: str(json['cod_ciudad']),
      genero: json['genero'] != null ? GeneroInfo.fromJson(json['genero']) : null,
      ciudad: json['ciudad'] != null ? CiudadInfo.fromJson(json['ciudad']) : null,
      empresa: json['empresa'] != null ? EmpresaInfo.fromJson(json['empresa']) : null,
      plan: json['plan'] != null ? PlanInfo.fromJson(json['plan']) : null,
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      tiene2fa: json['tiene_2fa'] ?? false,
      verificado: json['verificado'] ?? false,
      phoneNumberId: str(json['phone_number_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'nombre_completo': nombreCompleto,
      'email': email,
      'telefono': telefono,
      'codigo_telefono': codigoTelefono,
      'numero_completo': numeroCompleto,
      'foto': foto,
      'tipo_identificacion': tipoIdentificacion,
      'identificacion': identificacion,
      'genero_id': generoId,
      'pais_id': paisId,
      'cod_ciudad': codCiudad,
      'genero': genero?.toJson(),
      'ciudad': ciudad?.toJson(),
      'empresa': empresa?.toJson(),
      'plan': plan?.toJson(),
      'roles': roles,
      'tiene_2fa': tiene2fa,
      'verificado': verificado,
      'phone_number_id': phoneNumberId,
    };
  }
}

class GeneroInfo {
  final String? id; // CAMBIADO DE int? A String?
  final String? nombre;
  const GeneroInfo({this.id, this.nombre});
  
  factory GeneroInfo.fromJson(Map<String, dynamic> json) => GeneroInfo(
    id: json['id']?.toString(), 
    nombre: json['nombre']?.toString(),
  );
  
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
}

class CiudadInfo {
  final String? id; // CAMBIADO DE int? A String?
  final String? nombre;
  final PaisInfo? pais;
  const CiudadInfo({this.id, this.nombre, this.pais});
  
  factory CiudadInfo.fromJson(Map<String, dynamic> json) => CiudadInfo(
    id: json['id']?.toString(), 
    nombre: json['nombre']?.toString(),
    pais: json['pais'] != null ? PaisInfo.fromJson(json['pais']) : null,
  );
  
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'pais': pais?.toJson()};
}

class PaisInfo {
  final String? id; // CAMBIADO DE int? A String?
  final String? nombre;
  const PaisInfo({this.id, this.nombre});
  
  factory PaisInfo.fromJson(Map<String, dynamic> json) => PaisInfo(
    id: json['id']?.toString(), 
    nombre: json['nombre']?.toString(),
  );
  
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
}

class EmpresaInfo {
  final String? id;
  final String? nombre;
  final String? logo;
  const EmpresaInfo({this.id, this.nombre, this.logo});
  
  factory EmpresaInfo.fromJson(Map<String, dynamic> json) => EmpresaInfo(
    id: json['id']?.toString(),
    nombre: json['nombre']?.toString(),
    logo: json['logo']?.toString(),
  );
  
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'logo': logo};
}

class PlanInfo {
  final String? id; // CAMBIADO DE int? A String?
  final String? nombre;
  const PlanInfo({this.id, this.nombre});
  
  factory PlanInfo.fromJson(Map<String, dynamic> json) => PlanInfo(
    id: json['id']?.toString(), 
    nombre: json['nombre']?.toString(),
  );
  
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
}