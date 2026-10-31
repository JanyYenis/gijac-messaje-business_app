import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/message.dart';

/// In-memory sample data used to populate the UI.
class MockData {
  MockData._();

  static DateTime _t(int minutesAgo) =>
      DateTime.now().subtract(Duration(minutes: minutesAgo));

  static const contacts = <Contact>[
    Contact(
      id: 'c1',
      name: 'María González',
      phone: '+57 300 123 4567',
      about: 'Gerente de Compras',
      email: 'maria.g@empresa.com',
      company: 'Distribuidora Andina',
      tags: ['Cliente VIP', 'Mayorista'],
      isOnline: true,
      avatarColorValue: 0xFF25D366,
    ),
    Contact(
      id: 'c2',
      name: 'Carlos Ramírez',
      phone: '+57 311 987 6543',
      about: 'Soporte técnico',
      email: 'carlos.r@empresa.com',
      company: 'TechSolutions',
      tags: ['Soporte'],
      avatarColorValue: 0xFF3B82F6,
    ),
    Contact(
      id: 'c3',
      name: 'Laura Martínez',
      phone: '+57 320 555 1212',
      about: 'Pedido pendiente',
      company: 'Boutique Laura',
      tags: ['Nuevo'],
      isOnline: true,
      avatarColorValue: 0xFF128C7E,
    ),
    Contact(
      id: 'c4',
      name: 'Andrés Pérez',
      phone: '+57 315 444 8899',
      about: 'En reunión',
      tags: ['Prospecto'],
      avatarColorValue: 0xFFF59E0B,
    ),
    Contact(
      id: 'c5',
      name: 'Sofía Torres',
      phone: '+57 312 222 7766',
      about: 'Última vez hoy',
      tags: ['Cliente'],
      avatarColorValue: 0xFF8B5CF6,
    ),
  ];

  static List<Message> _conversation(Contact c) => [
        Message(
          id: 'm1',
          type: MessageType.text,
          source: MessageSource.contact,
          time: _t(58),
          text: 'Hola, buenas tardes. Quisiera información sobre sus productos.',
        ),
        Message(
          id: 'm2',
          type: MessageType.text,
          source: MessageSource.chatbot,
          time: _t(57),
          text:
              '¡Hola ${c.name.split(' ').first}! Soy el asistente virtual de GIJAC. ¿En qué puedo ayudarte hoy?',
        ),
        Message(
          id: 'm3',
          type: MessageType.buttons,
          source: MessageSource.chatbot,
          time: _t(57),
          text: 'Selecciona una opción para continuar:',
          actions: [
            MessageAction(label: 'Ver catálogo'),
            MessageAction(label: 'Hablar con un asesor'),
            MessageAction(label: 'Estado de mi pedido'),
          ],
        ),
        Message(
          id: 'm4',
          type: MessageType.text,
          source: MessageSource.contact,
          time: _t(55),
          text: 'Quiero ver el catálogo, por favor.',
          reactions: [Reaction(emoji: '👍', by: 'Asesor')],
        ),
        Message(
          id: 'm5',
          type: MessageType.pdf,
          source: MessageSource.agent,
          time: _t(54),
          fileName: 'Catalogo_2026.pdf',
          fileSize: '4.2 MB',
          caption: 'Aquí tienes nuestro catálogo actualizado.',
          status: MessageStatus.read,
        ),
        Message(
          id: 'm6',
          type: MessageType.image,
          source: MessageSource.agent,
          time: _t(53),
          caption: 'Este es nuestro producto más vendido.',
          status: MessageStatus.read,
        ),
        Message(
          id: 'm7',
          type: MessageType.list,
          source: MessageSource.ai,
          time: _t(50),
          text: 'Según tu interés, te recomiendo estas categorías:',
          actions: [
            MessageAction(
                label: 'Línea Premium', description: 'Productos exclusivos'),
            MessageAction(
                label: 'Ofertas', description: 'Descuentos de la semana'),
            MessageAction(
                label: 'Novedades', description: 'Recién llegados'),
          ],
        ),
        Message(
          id: 'm8',
          type: MessageType.audio,
          source: MessageSource.contact,
          time: _t(40),
          duration: '0:42',
        ),
        Message(
          id: 'm9',
          type: MessageType.location,
          source: MessageSource.contact,
          time: _t(38),
          locationName: 'Bodega Central',
          locationAddress: 'Cra 45 #23-10, Bogotá',
        ),
        Message(
          id: 'm10',
          type: MessageType.note,
          source: MessageSource.agent,
          time: _t(35),
          text:
              'Nota interna: cliente potencial mayorista, ofrecer descuento por volumen.',
        ),
        Message(
          id: 'm11',
          type: MessageType.form,
          source: MessageSource.n8n,
          time: _t(20),
          text: 'Formulario de cotización recibido vía automatización n8n:',
          actions: [
            MessageAction(label: 'Producto', description: 'Línea Premium x50'),
            MessageAction(label: 'Entrega', description: 'Bogotá - 3 días'),
            MessageAction(label: 'Total', description: '\$2.450.000 COP'),
          ],
        ),
        Message(
          id: 'm12',
          type: MessageType.text,
          source: MessageSource.contact,
          time: _t(8),
          text: 'Perfecto, muchas gracias por la información.',
        ),
      ];

  static List<Chat> chats() {
    final data = <Chat>[
      Chat(
        id: 'chat1',
        contact: contacts[0],
        lastMessage: 'Perfecto, muchas gracias por la información.',
        lastTime: _t(8),
        unreadCount: 2,
        status: ChatStatus.open,
        isPinned: true,
        assignedAgent: 'Juan Agente',
        messages: _conversation(contacts[0]),
      ),
      Chat(
        id: 'chat2',
        contact: contacts[1],
        lastMessage: 'El ticket #4821 ha sido resuelto.',
        lastTime: _t(25),
        status: ChatStatus.resolved,
        assignedAgent: 'Soporte',
        messages: _conversation(contacts[1]),
      ),
      Chat(
        id: 'chat3',
        contact: contacts[2],
        lastMessage: 'El bot está procesando tu pedido...',
        lastTime: _t(42),
        unreadCount: 5,
        status: ChatStatus.bot,
        messages: _conversation(contacts[2]),
      ),
      Chat(
        id: 'chat4',
        contact: contacts[3],
        lastMessage: 'Quedo atento a su respuesta.',
        lastTime: _t(120),
        status: ChatStatus.pending,
        messages: _conversation(contacts[3]),
      ),
      Chat(
        id: 'chat5',
        contact: contacts[4],
        lastMessage: 'Gracias por contactarnos.',
        lastTime: _t(300),
        isMuted: true,
        status: ChatStatus.resolved,
        messages: _conversation(contacts[4]),
      ),
    ];
    return data;
  }

  static List<AppNotification> notifications() => [
        AppNotification(
          id: 'n1',
          title: 'Nuevo mensaje',
          body: 'María González te ha enviado un mensaje.',
          time: _t(8),
          type: NotificationType.message,
        ),
        AppNotification(
          id: 'n2',
          title: 'Automatización ejecutada',
          body: 'El flujo "Bienvenida" se ejecutó 24 veces hoy.',
          time: _t(60),
          type: NotificationType.automation,
        ),
        AppNotification(
          id: 'n3',
          title: 'Respuesta de IA generada',
          body: 'La IA respondió 12 conversaciones automáticamente.',
          time: _t(95),
          type: NotificationType.ai,
          isRead: true,
        ),
        AppNotification(
          id: 'n4',
          title: 'Alerta de cuota',
          body: 'Has usado el 80% de tu plan mensual de mensajes.',
          time: _t(180),
          type: NotificationType.alert,
          isRead: true,
        ),
        AppNotification(
          id: 'n5',
          title: 'Dispositivo vinculado',
          body: 'Se conectó un nuevo dispositivo a tu cuenta.',
          time: _t(600),
          type: NotificationType.system,
          isRead: true,
        ),
      ];
}
