import 'dart:convert';
import 'message.dart';

enum ChatStatus { open, pending, resolved, bot }

class Contact {
  final String id;
  final String name;
  final String phone;
  final String about;
  final String? email;
  final String? company;
  final List<String> tags;
  final bool isOnline;
  final int avatarColorValue;

  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.about = 'Disponible',
    this.email,
    this.company,
    this.tags = const [],
    this.isOnline = false,
    this.avatarColorValue = 0xFF25D366,
  });

  String get initials {
    try {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) return '?';
      if (parts.length == 1) return parts.first[0].toUpperCase();
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } catch (e) {
      return '?';
    }
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    int colorValue = 0xFF25D366;
    final idStr = json['contact_id']?.toString() ?? json['id']?.toString() ?? '';
    if (idStr.isNotEmpty) {
      int hash = 0;
      for (int i = 0; i < idStr.length; i++) {
        hash += idStr.codeUnitAt(i);
      }
      final colors = [0xFF25D366, 0xFF128C7E, 0xFF3B82F6, 0xFF8B5CF6, 0xFFF59E0B, 0xFFEF4444, 0xFF06B6D4, 0xFFEC4899];
      colorValue = colors[hash % colors.length];
    }

    return Contact(
      id: json['contact_id']?.toString() ?? json['id']?.toString() ?? '',
      name: _cleanString(json['nombre'] ?? 'Sin nombre'),
      phone: json['telefono']?.toString() ?? '',
      about: 'Disponible',
      avatarColorValue: colorValue,
    );
  }

  // --- MÉTODOS DE CACHÉ ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'about': about,
        'email': email,
        'company': company,
        'tags': tags,
        'isOnline': isOnline,
        'avatarColorValue': avatarColorValue,
      };

  factory Contact.fromCachedJson(Map<String, dynamic> json) => Contact(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? 'Sin nombre',
        phone: json['phone'] ?? '',
        about: json['about'] ?? '',
        email: json['email'],
        company: json['company'],
        tags: List<String>.from(json['tags'] ?? []),
        isOnline: json['isOnline'] ?? false,
        avatarColorValue: json['avatarColorValue'] ?? 0xFF25D366,
      );

  static String _cleanString(dynamic input) {
    if (input == null) return 'Sin datos';
    try {
      final bytes = utf8.encode(input.toString());
      String cleaned = utf8.decode(bytes, allowMalformed: true);
      cleaned = cleaned.replaceAll('�', '').trim();
      return cleaned.isEmpty ? 'Sin datos' : cleaned;
    } catch (e) {
      return 'Sin datos';
    }
  }
}

class Chat {
  final String id;
  final Contact contact;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final ChatStatus status;
  final bool isPinned;
  final bool isMuted;
  final String? assignedAgent;
  final List<Message> messages;
  final String? rawTime;

  const Chat({
    required this.id,
    required this.contact,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCount = 0,
    this.status = ChatStatus.open,
    this.isPinned = false,
    this.isMuted = false,
    this.assignedAgent,
    this.messages = const [],
    this.rawTime,
  });

  /// false si el contacto aún no tiene conversación.
  bool get hasActivity => lastTime.millisecondsSinceEpoch > 0;

  factory Chat.fromJson(Map<String, dynamic> json) {
    String? timeText;
    DateTime? last;
    if (json['hora_ultimo_mensaje'] != null) {
      try {
        last = DateTime.parse(json['hora_ultimo_mensaje'].toString()).toLocal();
        timeText = _formatTime(last);
      } catch (e) {
        timeText = null;
      }
    }
    final bot = json['estado_chatbot']?.toString();
    final botOn = bot == '1' || bot == 'true' || bot == 'activo';
    final rawLast = (json['ultimo_mensaje'] ?? '').toString().trim();

    return Chat(
      id: json['id']?.toString() ?? json['numero_completo']?.toString() ?? '',
      contact: Contact.fromJson(json),
      lastMessage: rawLast.isEmpty ? 'Sin mensajes' : _cleanString(rawLast),
      lastTime: last ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: botOn ? ChatStatus.bot : ChatStatus.open,
      unreadCount: int.tryParse(json['no_leidos']?.toString() ?? '0') ?? 0,
      rawTime: timeText != null ? _cleanString(timeText) : null,
    );
  }

  // --- MÉTODOS DE CACHÉ ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'contact': contact.toJson(),
        'lastMessage': lastMessage,
        'lastTime': lastTime.toIso8601String(),
        'unreadCount': unreadCount,
        'status': status.name,
        'isPinned': isPinned,
        'isMuted': isMuted,
        'assignedAgent': assignedAgent,
        'rawTime': rawTime,
      };

  factory Chat.fromCachedJson(Map<String, dynamic> json) => Chat(
        id: json['id']?.toString() ?? '',
        contact: Contact.fromCachedJson(json['contact'] ?? {}),
        lastMessage: json['lastMessage'] ?? '',
        lastTime: DateTime.tryParse(json['lastTime'] ?? '') ?? DateTime.now(),
        unreadCount: json['unreadCount'] ?? 0,
        status: ChatStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ChatStatus.open,
        ),
        isPinned: json['isPinned'] ?? false,
        isMuted: json['isMuted'] ?? false,
        assignedAgent: json['assignedAgent'],
        rawTime: json['rawTime'],
      );

  static String _cleanString(dynamic input) {
    if (input == null) return 'Sin datos';
    try {
      final bytes = utf8.encode(input.toString());
      String cleaned = utf8.decode(bytes, allowMalformed: true);
      cleaned = cleaned.replaceAll('�', '').trim();
      return cleaned.isEmpty ? 'Sin datos' : cleaned;
    } catch (e) {
      return 'Sin datos';
    }
  }

  static String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inMinutes < 1) return 'Ahora';
      if (difference.inHours < 1) return 'Hace ${difference.inMinutes} min';
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final min = dateTime.minute.toString().padLeft(2, '0');
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}