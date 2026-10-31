import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/chat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/status_badge.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(filteredChatsProvider);
    final filter = ref.watch(chatFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newChat(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) =>
                  ref.read(chatSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Buscar conversaciones',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(ref, ChatFilter.all, 'Todos', filter),
                _chip(ref, ChatFilter.unread, 'No leídos', filter),
                _chip(ref, ChatFilter.bot, 'Chatbot', filter),
                _chip(ref, ChatFilter.resolved, 'Resueltos', filter),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: chats.isEmpty
                ? const Center(child: Text('No hay conversaciones'))
                : RefreshIndicator(
                    onRefresh: () => ref.read(chatsProvider.notifier).loadChats(),
                    child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 84),
                    itemBuilder: (_, i) =>
                        _ChatTile(chat: chats[i]),
                  )),
          ),
        ],
      ),
    );
  }

  void _newChat(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ContactPicker(),
    );
  }

  Widget _chip(
      WidgetRef ref, ChatFilter value, String label, ChatFilter current) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => ref.read(chatFilterProvider.notifier).state = value,
        showCheckmark: false,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? AppColors.secondary : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        ref.read(chatsProvider.notifier).markRead(chat.id);
        context.push(
          '/chats/${chat.id}',
          extra: {
            'nombre': chat.contact.name,
          },
        );
      },
      leading: AppAvatar(
        initials: chat.contact.initials,
        colorValue: chat.contact.avatarColorValue,
        isOnline: chat.contact.isOnline,
        radius: 26,
      ),
      title: Row(
        children: [
          if (chat.isPinned)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 14, color: AppColors.secondary),
            ),
          Expanded(
            child: Text(chat.contact.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (chat.hasActivity)
          Text(
            TimeFormat.relative(chat.lastTime),
            style: theme.textTheme.bodySmall?.copyWith(
              color: chat.unreadCount > 0
                  ? AppColors.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight:
                  chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            _statusIcon(),
            Expanded(
              child: Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (chat.isMuted)
              Icon(Icons.volume_off,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            if (chat.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 22, minHeight: 22),
                child: Text('${chat.unreadCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon() {
    final (label, color) = switch (chat.status) {
      ChatStatus.bot => ('Bot', AppColors.botAccent),
      ChatStatus.pending => ('Pend.', AppColors.warning),
      ChatStatus.resolved => ('OK', AppColors.success),
      ChatStatus.open => ('', AppColors.primary),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: StatusBadge(label: label, color: color),
    );
  }
}


class _ContactPicker extends ConsumerStatefulWidget {
  const _ContactPicker();

  @override
  ConsumerState<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends ConsumerState<_ContactPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(chatsProvider);
    final q = _q.toLowerCase();
    final list = all
        .where((c) =>
            q.isEmpty ||
            c.contact.name.toLowerCase().contains(q) ||
            c.contact.phone.contains(q))
        .toList();
    final height = MediaQuery.of(context).size.height * 0.75;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar contacto o teléfono',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return ListTile(
                          leading: AppAvatar(
                            initials: c.contact.initials,
                            colorValue: c.contact.avatarColorValue,
                            radius: 22,
                          ),
                          title: Text(c.contact.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.contact.phone),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/chats/${c.id}',
                                extra: {'nombre': c.contact.name});
                          },
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