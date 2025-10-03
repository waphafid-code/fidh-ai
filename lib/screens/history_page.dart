import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fidh_ai/models/chat_session.dart';
import 'package:fidh_ai/screens/home_page.dart';
import 'package:fidh_ai/services/firestore_service.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirestoreService _firestoreService = FirestoreService();

  void _startNewChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Percakapan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _startNewChat,
            tooltip: "Percakapan Baru",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getChatHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text("Terjadi error saat memuat riwayat."),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final sessions = snapshot.data!.docs
              .map((doc) => ChatSession.fromFirestore(doc))
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Tablet / Desktop
                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: constraints.maxWidth / 250,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) =>
                      _buildHistoryCard(sessions[index]),
                );
              } else {
                // Mobile
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) =>
                      _buildHistoryCard(sessions[index]),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 24),
          Text(
            "Belum Ada Riwayat",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Mulai percakapan baru untuk melihatnya di sini.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ChatSession session) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(
          session.title.isNotEmpty ? session.title : "Tanpa Judul",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(session.formattedDate),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomePage(chatId: session.id),
            ),
          );
        },
      ),
    );
  }
}
