import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../widgets/section_card.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);
    final notifier = ref.read(privacySettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Privacidad'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          SectionCard(
            title: 'Visibilidad',
            children: [
              _DropdownTile(
                icon: Icons.access_time,
                label: 'Hora de ult. vez',
                value: settings.lastSeen,
                options: const ['Todos', 'Mis contactos', 'Nadie'],
                onChanged: notifier.setLastSeen,
              ),
              _DropdownTile(
                icon: Icons.account_circle_outlined,
                label: 'Foto del perfil',
                value: settings.profilePhoto,
                options: const ['Todos', 'Mis contactos', 'Nadie'],
                onChanged: notifier.setProfilePhoto,
              ),
              _DropdownTile(
                icon: Icons.info_outline,
                label: 'Info.',
                value: settings.about,
                options: const ['Todos', 'Mis contactos', 'Nadie'],
                onChanged: notifier.setAbout,
              ),
            ],
          ),
          SectionCard(
            title: 'Mensajes',
            children: [
              SwitchListTile(
                secondary: Icon(Icons.done_all, color: theme.colorScheme.primary),
                title: const Text('Confirmaciones de lectura'),
                subtitle: const Text(
                  'Si las desactivas, no podras ver las confirmaciones de lectura de otras personas.',
                ),
                value: settings.readReceipts,
                onChanged: (_) => notifier.toggleReadReceipts(),
              ),
            ],
          ),
          SectionCard(
            title: 'Grupos',
            children: [
              _DropdownTile(
                icon: Icons.group_add_outlined,
                label: 'Quien puede anadirme',
                value: settings.groupAdd,
                options: const ['Todos', 'Mis contactos', 'Nadie'],
                onChanged: notifier.setGroupAdd,
              ),
            ],
          ),
          SectionCard(
            title: 'Avanzado',
            children: [
              SwitchListTile(
                secondary: Icon(Icons.block, color: theme.colorScheme.primary),
                title: const Text('Bloquear capturas de pantalla'),
                value: settings.blockScreenshots,
                onChanged: (_) => notifier.toggleBlockScreenshots(),
              ),
              ListTile(
                leading: Icon(Icons.person_off_outlined, color: theme.colorScheme.primary),
                title: const Text('Contactos bloqueados'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${settings.blockedCount}', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
