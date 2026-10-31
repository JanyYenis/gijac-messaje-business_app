import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';

class ContactInfoScreen extends ConsumerWidget {
  const ContactInfoScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatsProvider).firstWhere((c) => c.id == chatId);
    final c = chat.contact;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.secondary,
                padding: const EdgeInsets.only(top: 60, bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppAvatar(
                      initials: c.initials,
                      colorValue: c.avatarColorValue,
                      radius: 44,
                      isOnline: c.isOnline,
                    ),
                    const SizedBox(height: 12),
                    Text(c.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(c.phone,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _action(Icons.message, 'Mensaje'),
                  _action(Icons.call, 'Llamar'),
                  _action(Icons.videocam, 'Video'),
                  _action(Icons.search, 'Buscar'),
                ],
              ),
              const SizedBox(height: 20),
              if (c.tags.isNotEmpty) ...[
                const SectionHeader(title: 'Etiquetas'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: c.tags
                      .map((t) => StatusBadge(label: t, color: AppColors.blue))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
              const SectionHeader(title: 'Información'),
              GroupedCard(children: [
                AppTile(
                    icon: Icons.info_outline,
                    title: c.about,
                    subtitle: 'Estado'),
                if (c.email != null)
                  AppTile(
                      icon: Icons.email_outlined,
                      title: c.email!,
                      subtitle: 'Correo'),
                if (c.company != null)
                  AppTile(
                      icon: Icons.business_outlined,
                      title: c.company!,
                      subtitle: 'Empresa'),
                AppTile(
                    icon: Icons.phone_outlined,
                    title: c.phone,
                    subtitle: 'Teléfono'),
              ]),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Gestión'),
              GroupedCard(children: [
                AppTile(
                    icon: Icons.support_agent,
                    title: chat.assignedAgent ?? 'Sin asignar',
                    subtitle: 'Agente asignado',
                    onTap: () {}),
                AppTile(
                    icon: Icons.label_outline,
                    title: 'Administrar etiquetas',
                    onTap: () {}),
                AppTile(
                    icon: Icons.smart_toy_outlined,
                    iconColor: AppColors.aiAccent,
                    title: 'Respuestas con IA',
                    trailing: Switch(value: true, onChanged: (_) {})),
              ]),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Multimedia compartida'),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      i.isEven ? Icons.image : Icons.insert_drive_file,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GroupedCard(children: [
                AppTile(
                    icon: Icons.block,
                    iconColor: AppColors.danger,
                    title: 'Bloquear contacto',
                    onTap: () {}),
                AppTile(
                    icon: Icons.report_outlined,
                    iconColor: AppColors.danger,
                    title: 'Reportar',
                    onTap: () {}),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: () {}, icon: Icon(icon)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
