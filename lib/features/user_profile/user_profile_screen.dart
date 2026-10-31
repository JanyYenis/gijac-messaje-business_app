import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';
import '../../core/providers/user_provider.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(userProvider);
    final user = userState.user!;

    // Calcular iniciales dinámicamente
    final parts = user.nombreCompleto.split(' ').where((s) => s.isNotEmpty).take(2).toList();
    final initials = parts.map((s) => s[0].toUpperCase()).join();
    
    // Obtener el primer rol o un valor por defecto
    final role = user.roles.isNotEmpty ? user.roles.first.capitalize() : 'Sin rol asignado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de usuario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final ok = await ref.read(userProvider.notifier).refreshProfile();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(ok ? 'Perfil actualizado' : 'No se pudo actualizar. Revisa tu conexión.')));
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
            child: const Text('Editar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                AppAvatar(
                  initials: initials, // Antes: user.initials
                  imageUrl: user.foto,
                  radius: 48,
                  colorValue: 0xFF3B82F6, // Antes: user.avatarColorValue
                ),

                const SizedBox(height: 12),

                Text(
                  user.nombreCompleto, // Antes: user.name
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  role, // Antes: user.role
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                StatusBadge(
                  label: user.verificado ? 'Verificado' : 'No verificado', // Adaptado al dato real
                  color: user.verificado ? AppColors.primary : Colors.grey,
                  icon: Icons.verified,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _miniStat(
                  theme,
                  '1.2k',
                  'Atendidos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                  theme,
                  '98%',
                  'Satisfacción',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                  theme,
                  '2.1m',
                  'Resp. media',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const SectionHeader(
            title: 'Datos personales',
          ),

          GroupedCard(
            children: [
              AppTile(
                icon: Icons.person_outline,
                title: user.nombreCompleto, // Antes: user.name
                subtitle: 'Nombre completo',
              ),

              AppTile(
                icon: Icons.alternate_email,
                title: user.email,
                subtitle: 'Correo corporativo',
              ),

              AppTile(
                icon: Icons.phone_outlined,
                title: user.numeroCompleto ?? 'No registrado', // Antes: user.phone
                subtitle: 'Teléfono',
              ),

              AppTile(
                icon: Icons.badge_outlined,
                title: user.id, // Antes: user.employeeCode
                subtitle: 'ID de usuario',
              ),
            ],
          ),

          const SizedBox(height: 20),

          const SectionHeader(
            title: 'Rol y permisos',
          ),

          GroupedCard(
            children: [
              AppTile(
                icon: Icons.shield_outlined,
                iconColor: AppColors.secondary,
                title: role, // Antes: user.role
                subtitle: 'Rol asignado',
              ),

              AppTile(
                icon: Icons.business_outlined, // Cambiado a ícono de empresa
                title: user.empresa?.nombre ?? 'Sin empresa', // Antes: user.department
                subtitle: 'Empresa',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    ThemeData theme,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extensión auxiliar para capitalizar la primera letra
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}