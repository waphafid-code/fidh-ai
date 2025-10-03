// lib/models/chat_session.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  // Getter untuk memformat tanggal dengan cantik
  String get formattedDate {
    return DateFormat('d MMM yyyy, HH:mm').format(createdAt);
  }

  // Factory constructor untuk membuat objek ChatSession dari dokumen Firestore
  factory ChatSession.fromFirestore(QueryDocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      id: doc.id,
      title: data['title'] ?? 'Untitled Chat',
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}
