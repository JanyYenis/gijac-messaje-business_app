import 'package:flutter/material.dart';

/// Texto con el formato de WhatsApp: *negrilla*, _cursiva_, ~tachado~, `código` y ```bloque```.
/// Se usa igual que Text: WhatsappText('Hola *Esteban*', style: ...)
class WhatsappText extends StatelessWidget {
  const WhatsappText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  // El marcador debe ir pegado al texto y no dentro de una palabra (como en WhatsApp)
  static final RegExp _re = RegExp(
    r'(?<![\p{L}\p{N}])(?:(```[\s\S]+?```)|\*([^\s*](?:[^*\n]*[^\s*])?)\*|_([^\s_](?:[^_\n]*[^\s_])?)_|~([^\s~](?:[^~\n]*[^\s~])?)~|`([^`\n]+)`)(?![\p{L}\p{N}])',
    unicode: true,
  );

  static List<InlineSpan> _parse(String t, [int nivel = 0]) {
    final out = <InlineSpan>[];
    var i = 0;
    for (final m in _re.allMatches(t)) {
      if (m.start > i) out.add(TextSpan(text: t.substring(i, m.start)));
      if (m.group(1) != null) {
        final g = m.group(1)!;
        out.add(TextSpan(
          text: g.substring(3, g.length - 3).trim(),
          style: const TextStyle(fontFamily: 'monospace'),
        ));
      } else if (m.group(2) != null) {
        out.add(TextSpan(
          children: nivel < 3 ? _parse(m.group(2)!, nivel + 1) : [TextSpan(text: m.group(2))],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(3) != null) {
        out.add(TextSpan(
          children: nivel < 3 ? _parse(m.group(3)!, nivel + 1) : [TextSpan(text: m.group(3))],
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(4) != null) {
        out.add(TextSpan(
          children: nivel < 3 ? _parse(m.group(4)!, nivel + 1) : [TextSpan(text: m.group(4))],
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ));
      } else {
        out.add(TextSpan(
          text: m.group(5),
          style: const TextStyle(fontFamily: 'monospace'),
        ));
      }
      i = m.end;
    }
    if (i < t.length) out.add(TextSpan(text: t.substring(i)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(TextSpan(style: base, children: _parse(text)));
  }
}
