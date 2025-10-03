import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatParticipant { user, model }

class ChatMessage {
  final String text;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final ChatParticipant participant;

  ChatMessage({
    required this.text,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    required this.participant,
  });

  // FIX: Tambahkan factory constructor ini
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      text: data['text'] ?? "",
      participant: data['participant'] == 'user'
          ? ChatParticipant.user
          : ChatParticipant.model,
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
    );
  }
}
