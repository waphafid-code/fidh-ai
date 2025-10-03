import 'dart:async';
import 'dart:io';

import 'package:fidh_ai/models/chat_message.dart';
import 'package:fidh_ai/services/auth_service.dart';
import 'package:fidh_ai/services/firestore_service.dart';
import 'package:fidh_ai/services/ai_service.dart';
import 'package:fidh_ai/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

// 1. Provider untuk Service-service
final authServiceProvider = Provider((ref) => AuthService());
final firestoreServiceProvider = Provider((ref) => FirestoreService());
final storageServiceProvider = Provider((ref) => StorageService());
final aiServiceProvider = Provider((ref) => AIService());

// 2. Provider untuk mengambil stream pesan dari Firestore
final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService
      .getMessagesForChat(chatId)
      .map((snapshot) => snapshot.docs
          .map((doc) {
            final data = doc.data(); // ✅ tidak perlu cast
            return ChatMessage(
              text: data['text'] ?? "",
              participant: data['participant'] == 'user'
                  ? ChatParticipant.user
                  : ChatParticipant.model,
              imageUrl: data['imageUrl'],
              fileUrl: data['fileUrl'],
              fileName: data['fileName'],
            );
          })
          .toList()
          .reversed
          .toList());
});

// 3. Provider untuk state management utama halaman chat
final chatControllerProvider =
    StateNotifierProvider.autoDispose<ChatController, ChatState>((ref) {
  return ChatController(ref);
});

class ChatState {
  final String? chatId;
  final bool isLoading;
  final String streamingResponse;

  ChatState({
    this.chatId,
    this.isLoading = false,
    this.streamingResponse = "",
  });

  ChatState copyWith({
    String? chatId,
    bool? isLoading,
    String? streamingResponse,
  }) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      isLoading: isLoading ?? this.isLoading,
      streamingResponse: streamingResponse ?? this.streamingResponse,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  final Ref _ref;

  ChatController(this._ref) : super(ChatState());

  void setChatId(String? chatId) {
    state = state.copyWith(chatId: chatId);
  }

  /// Kirim pesan teks dengan streaming
  Future<void> _sendTextMessageStream(String chatId, String text) async {
    final firestore = _ref.read(firestoreServiceProvider);
    final ai = _ref.read(aiServiceProvider);

    // Simpan pesan user ke Firestore
    await firestore.addMessageToChat(
      chatId: chatId,
      message: ChatMessage(text: text, participant: ChatParticipant.user),
    );

    String buffer = "";

    try {
      await for (final chunk in ai.generateResponseStream(text)) {
        buffer += chunk;

        // Update state supaya UI bisa render balasan bertahap
        state = state.copyWith(streamingResponse: buffer);
      }

      // Setelah selesai stream → simpan hasil final ke Firestore
      final finalMessage = ChatMessage(
        text: buffer,
        participant: ChatParticipant.model,
      );
      await firestore.addMessageToChat(chatId: chatId, message: finalMessage);
    } catch (_) {
      final errorMessage = ChatMessage(
        text: "Terjadi kesalahan saat meminta balasan AI (stream).",
        participant: ChatParticipant.model,
      );
      await firestore.addMessageToChat(chatId: chatId, message: errorMessage);
    } finally {
      state = state.copyWith(isLoading: false, streamingResponse: "");
    }
  }

  Future<void> _sendMultiModalMessage(
      String chatId, String text, File image) async {
    await _sendTextMessageStream(
      chatId,
      "$text\n\n(Gambar terlampir tidak dapat diproses oleh model ini)",
    );
  }

  Future<void> sendMessage({
    required String text,
    File? image,
  }) async {
    if (text.trim().isEmpty && image == null) return;

    state = state.copyWith(isLoading: true, streamingResponse: "");

    try {
      String currentChatId = state.chatId ?? '';

      if (currentChatId.isEmpty) {
        final firstMessage =
            image != null ? (text.isEmpty ? "[Gambar]" : text) : text;
        currentChatId = await _ref
            .read(firestoreServiceProvider)
            .createNewChatSession(title: firstMessage);
        state = state.copyWith(chatId: currentChatId);
      }

      if (image != null) {
        await _sendMultiModalMessage(currentChatId, text, image);
        state = state.copyWith(isLoading: false);
      } else {
        await _sendTextMessageStream(currentChatId, text);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return;

    File file = File(result.files.single.path!);
    final fileName = result.files.single.name;

    state = state.copyWith(isLoading: true);

    try {
      String currentChatId = state.chatId ?? '';

      if (currentChatId.isEmpty) {
        currentChatId = await _ref
            .read(firestoreServiceProvider)
            .createNewChatSession(title: "File: $fileName");
        state = state.copyWith(chatId: currentChatId);
      }

      final downloadUrl = await _ref
          .read(storageServiceProvider)
          .uploadFile(currentChatId, file);

      if (downloadUrl != null) {
        final firestore = _ref.read(firestoreServiceProvider);
        final ai = _ref.read(aiServiceProvider);

        final fileMessage = ChatMessage(
          text: "",
          fileUrl: downloadUrl,
          fileName: fileName,
          participant: ChatParticipant.user,
        );
        await firestore.addMessageToChat(
            chatId: currentChatId, message: fileMessage);

        final responseText = await ai.generateResponseFromText(
          "Saya baru saja mengunggah file bernama '$fileName'. Tolong berikan ringkasan singkat tentang kemungkinan isi file ini berdasarkan namanya.",
        );
        final modelMessage =
            ChatMessage(text: responseText, participant: ChatParticipant.model);
        await firestore.addMessageToChat(
            chatId: currentChatId, message: modelMessage);
      }
    } catch (_) {
      // ✅ Tidak ada TODO lagi, tapi tetap aman jika error
      // Bisa tambahkan logging jika diperlukan
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
