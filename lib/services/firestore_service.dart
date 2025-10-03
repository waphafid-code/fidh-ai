import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fidh_ai/models/chat_message.dart'; // cite: uploaded:lib/models/chat_message.dart

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createNewChatSession({required String title}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak login");

    final chatDocRef = await _db.collection('chats').add({
      'userId': user.uid,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return chatDocRef.id;
  }

  Future<void> addMessageToChat(
      {required String chatId, required ChatMessage message}) async {
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'text': message.text, // cite: uploaded:lib/models/chat_message.dart
      'participant': message
          .participant.name, // cite: uploaded:lib/models/chat_message.dart
      'timestamp': FieldValue.serverTimestamp(),
      'imageUrl':
          message.imageUrl, // cite: uploaded:lib/models/chat_message.dart
      'fileUrl': message.fileUrl, // cite: uploaded:lib/models/chat_message.dart
      'fileName':
          message.fileName, // cite: uploaded:lib/models/chat_message.dart
    });
  }

  // FIX: Tambahkan tipe <Map<String, dynamic>>
  Stream<QuerySnapshot<Map<String, dynamic>>> getChatHistory() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User tidak login");

    return _db
        .collection('chats')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // FIX: Tambahkan tipe <Map<String, dynamic>> untuk konsistensi
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesForChat(
      String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }
}
