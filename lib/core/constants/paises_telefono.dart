/// Países para elegir el indicativo del teléfono (nombre, código ISO y indicativo sin "+").
class PaisTelefono {
  const PaisTelefono(this.nombre, this.iso, this.dial);

  final String nombre;
  final String iso;
  final String dial;

  /// Bandera como emoji a partir del código ISO (funciona en Android y iPhone)
  String get bandera => String.fromCharCodes(iso.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65));

  /// Primer país con ese indicativo (acepta "57" o "+57"); null si no existe
  static PaisTelefono? porIndicativo(String? dial) {
    final d = (dial ?? '').replaceAll('+', '').trim();
    if (d.isEmpty) return null;
    for (final p in lista) {
      if (p.dial == d) return p;
    }
    return null;
  }

  static const colombia = PaisTelefono('Colombia', 'CO', '57');

  static const lista = <PaisTelefono>[
    colombia,
    PaisTelefono('México', 'MX', '52'),
    PaisTelefono('Argentina', 'AR', '54'),
    PaisTelefono('Bolivia', 'BO', '591'),
    PaisTelefono('Brasil', 'BR', '55'),
    PaisTelefono('Chile', 'CL', '56'),
    PaisTelefono('Costa Rica', 'CR', '506'),
    PaisTelefono('Cuba', 'CU', '53'),
    PaisTelefono('Ecuador', 'EC', '593'),
    PaisTelefono('El Salvador', 'SV', '503'),
    PaisTelefono('Guatemala', 'GT', '502'),
    PaisTelefono('Honduras', 'HN', '504'),
    PaisTelefono('Nicaragua', 'NI', '505'),
    PaisTelefono('Panamá', 'PA', '507'),
    PaisTelefono('Paraguay', 'PY', '595'),
    PaisTelefono('Perú', 'PE', '51'),
    PaisTelefono('Uruguay', 'UY', '598'),
    PaisTelefono('Venezuela', 'VE', '58'),
    PaisTelefono('Estados Unidos', 'US', '1'),
    PaisTelefono('Canadá', 'CA', '1'),
    PaisTelefono('Puerto Rico', 'PR', '1'),
    PaisTelefono('República Dominicana', 'DO', '1'),
    PaisTelefono('Jamaica', 'JM', '1'),
    PaisTelefono('Trinidad y Tobago', 'TT', '1'),
    PaisTelefono('Bahamas', 'BS', '1'),
    PaisTelefono('Barbados', 'BB', '1'),
    PaisTelefono('Haití', 'HT', '509'),
    PaisTelefono('Belice', 'BZ', '501'),
    PaisTelefono('Guyana', 'GY', '592'),
    PaisTelefono('Surinam', 'SR', '597'),
    PaisTelefono('España', 'ES', '34'),
    PaisTelefono('Portugal', 'PT', '351'),
    PaisTelefono('Francia', 'FR', '33'),
    PaisTelefono('Alemania', 'DE', '49'),
    PaisTelefono('Italia', 'IT', '39'),
    PaisTelefono('Reino Unido', 'GB', '44'),
    PaisTelefono('Irlanda', 'IE', '353'),
    PaisTelefono('Países Bajos', 'NL', '31'),
    PaisTelefono('Bélgica', 'BE', '32'),
    PaisTelefono('Luxemburgo', 'LU', '352'),
    PaisTelefono('Suiza', 'CH', '41'),
    PaisTelefono('Austria', 'AT', '43'),
    PaisTelefono('Suecia', 'SE', '46'),
    PaisTelefono('Noruega', 'NO', '47'),
    PaisTelefono('Dinamarca', 'DK', '45'),
    PaisTelefono('Finlandia', 'FI', '358'),
    PaisTelefono('Islandia', 'IS', '354'),
    PaisTelefono('Polonia', 'PL', '48'),
    PaisTelefono('República Checa', 'CZ', '420'),
    PaisTelefono('Eslovaquia', 'SK', '421'),
    PaisTelefono('Hungría', 'HU', '36'),
    PaisTelefono('Rumanía', 'RO', '40'),
    PaisTelefono('Bulgaria', 'BG', '359'),
    PaisTelefono('Grecia', 'GR', '30'),
    PaisTelefono('Croacia', 'HR', '385'),
    PaisTelefono('Serbia', 'RS', '381'),
    PaisTelefono('Eslovenia', 'SI', '386'),
    PaisTelefono('Lituania', 'LT', '370'),
    PaisTelefono('Letonia', 'LV', '371'),
    PaisTelefono('Estonia', 'EE', '372'),
    PaisTelefono('Malta', 'MT', '356'),
    PaisTelefono('Chipre', 'CY', '357'),
    PaisTelefono('Turquía', 'TR', '90'),
    PaisTelefono('Rusia', 'RU', '7'),
    PaisTelefono('Ucrania', 'UA', '380'),
    PaisTelefono('Israel', 'IL', '972'),
    PaisTelefono('Emiratos Árabes Unidos', 'AE', '971'),
    PaisTelefono('Arabia Saudita', 'SA', '966'),
    PaisTelefono('Catar', 'QA', '974'),
    PaisTelefono('Jordania', 'JO', '962'),
    PaisTelefono('Líbano', 'LB', '961'),
    PaisTelefono('Irak', 'IQ', '964'),
    PaisTelefono('Irán', 'IR', '98'),
    PaisTelefono('Egipto', 'EG', '20'),
    PaisTelefono('Marruecos', 'MA', '212'),
    PaisTelefono('Argelia', 'DZ', '213'),
    PaisTelefono('Túnez', 'TN', '216'),
    PaisTelefono('Nigeria', 'NG', '234'),
    PaisTelefono('Ghana', 'GH', '233'),
    PaisTelefono('Kenia', 'KE', '254'),
    PaisTelefono('Etiopía', 'ET', '251'),
    PaisTelefono('Angola', 'AO', '244'),
    PaisTelefono('Mozambique', 'MZ', '258'),
    PaisTelefono('Sudáfrica', 'ZA', '27'),
    PaisTelefono('India', 'IN', '91'),
    PaisTelefono('Pakistán', 'PK', '92'),
    PaisTelefono('Bangladés', 'BD', '880'),
    PaisTelefono('China', 'CN', '86'),
    PaisTelefono('Hong Kong', 'HK', '852'),
    PaisTelefono('Taiwán', 'TW', '886'),
    PaisTelefono('Japón', 'JP', '81'),
    PaisTelefono('Corea del Sur', 'KR', '82'),
    PaisTelefono('Filipinas', 'PH', '63'),
    PaisTelefono('Indonesia', 'ID', '62'),
    PaisTelefono('Malasia', 'MY', '60'),
    PaisTelefono('Singapur', 'SG', '65'),
    PaisTelefono('Tailandia', 'TH', '66'),
    PaisTelefono('Vietnam', 'VN', '84'),
    PaisTelefono('Australia', 'AU', '61'),
    PaisTelefono('Nueva Zelanda', 'NZ', '64'),
  ];
}
