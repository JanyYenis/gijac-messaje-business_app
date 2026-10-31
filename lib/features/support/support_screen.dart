import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/section_card.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _urlTickets = 'https://message-business.gijac.com/tickets';
  static const _urlFaq = 'https://message-business.gijac.com/preguntas-frecuentes';
  static const _urlPrivacidad = 'https://message-business.gijac.com/politicas-de-privacidad';
  static const _urlTerminos = 'https://message-business.gijac.com/terminos-y-condiciones';
  static const _urlEliminacion = 'https://message-business.gijac.com/eliminacion-de-datos';
  static const _correo = 'soporte@gijac.co';
  static const _telefono = '573171789584';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Ayuda y soporte'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Material(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent, size: 36, color: color),
                    const SizedBox(height: 12),
                    Text('Centro de ayuda GIJAC', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      'Crea un ticket o escríbenos y te ayudamos con cualquier problema.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SectionCard(
            title: 'Contacto',
            children: [
              _enlace(context, Icons.confirmation_number_outlined, 'Crear un ticket', 'Se abre en la web', _urlTickets),
              _enlace(context, Icons.email_outlined, 'Enviar correo', _correo, 'mailto:$_correo?subject=Soporte%20GIJAC%20Message%20Business', abrirFuera: false),
              _enlace(context, Icons.phone_outlined, 'Llamar', '+57 317 178 9584', 'tel:+$_telefono', abrirFuera: false),
            ],
          ),
          SectionCard(
            title: 'Preguntas frecuentes',
            children: [
              const _FaqTile(
                question: '¿Cómo vinculo la app con mi cuenta?',
                answer: 'Entra a la web, genera el código QR de vinculación y escanéalo con la app. Si el código venció (dura pocos minutos), genera uno nuevo.',
              ),
              const _FaqTile(
                question: '¿Por qué no me llegan las notificaciones?',
                answer:
                    'Revisa que las notificaciones estén activas en Ajustes y que el teléfono permita a GIJAC funcionar sin restricciones de batería y con inicio automático. En algunos teléfonos (Oppo, Xiaomi, etc.) cerrar la app deslizándola desde recientes detiene los avisos; bloquéala en recientes para evitarlo.',
              ),
              const _FaqTile(
                question: '¿Por qué no puedo responder a un contacto?',
                answer:
                    'WhatsApp solo permite escribir libremente durante las 24 horas siguientes al último mensaje del cliente. Pasado ese tiempo debes iniciar la conversación con una plantilla aprobada.',
              ),
              const _FaqTile(
                question: '¿Cómo cambio mi contraseña?',
                answer: 'Desde Ajustes > Seguridad > Cambiar contraseña. Te llevará a tu perfil en la web, donde se actualiza.',
              ),
              const _FaqTile(
                question: '¿Cómo actualizo mis datos o mi foto?',
                answer: 'Entra a tu perfil desde Ajustes y toca Editar. Los cambios se ven igual en la web.',
              ),
              const _FaqTile(
                question: '¿Por qué no puedo editar el perfil de WhatsApp Business?',
                answer: 'Meta no permite editar el perfil de los números de prueba. Con un número de producción puedes cambiar la foto, descripción, correo, categoría y sitios web.',
              ),
              const _FaqTile(
                question: '¿Qué significa que el bot atienda un chat?',
                answer: 'La conversación se responde automáticamente según el chatbot configurado. Puedes tomar el control y escribir tú en cualquier momento.',
              ),
              const _FaqTile(
                question: '¿Dónde administro el catálogo?',
                answer: 'Desde la web. En Ajustes > Perfil de WhatsApp Business > Catálogo se abre directamente.',
              ),
              _enlace(context, Icons.open_in_new, 'Ver todas las preguntas frecuentes', 'En la web', _urlFaq),
            ],
          ),
          SectionCard(
            title: 'Legal',
            children: [
              _enlace(context, Icons.description_outlined, 'Términos y condiciones', null, _urlTerminos),
              _enlace(context, Icons.privacy_tip_outlined, 'Políticas de privacidad', null, _urlPrivacidad),
              _enlace(context, Icons.delete_outline, 'Eliminación de datos', null, _urlEliminacion),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('GIJAC v1.0.0', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _enlace(BuildContext context, IconData icono, String titulo, String? subtitulo, String url, {bool abrirFuera = true}) {
    final color = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icono, color: color),
      title: Text(titulo),
      subtitle: subtitulo == null ? null : Text(subtitulo),
      trailing: Icon(abrirFuera ? Icons.open_in_new : Icons.chevron_right, size: 18),
      onTap: () async {
        var ok = false;
        try {
          ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {}
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir. Intenta de nuevo.')));
        }
      },
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
      title: Text(question, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(answer, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
        ),
      ],
    );
  }
}