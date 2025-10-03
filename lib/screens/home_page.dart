import 'dart:io';
import 'package:fidh_ai/models/chat_message.dart';
import 'package:fidh_ai/providers/chat_providers.dart';
import 'package:fidh_ai/screens/history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends ConsumerStatefulWidget {
  final String? chatId;
  const HomePage({super.key, this.chatId});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final SpeechToText _speechToText = SpeechToText();

  File? _selectedImage;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(chatControllerProvider.notifier).setChatId(widget.chatId));
    _initSpeech();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    if (mounted) setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) setState(() => _textController.text = result.recognizedWords);
  }

  void _sendMessage() {
    if (_speechToText.isListening) _stopListening();

    ref.read(chatControllerProvider.notifier).sendMessage(
          text: _textController.text,
          image: _selectedImage,
        );
    _textController.clear();
    setState(() => _selectedImage = null);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final messagesAsyncValue = chatState.chatId != null
        ? ref.watch(messagesStreamProvider(chatState.chatId!))
        : const AsyncData<List<ChatMessage>>([]);

    ref.listen(messagesStreamProvider(chatState.chatId ?? ''), (_, next) {
      if (next.hasValue && next.value!.isNotEmpty) {
        Future.microtask(() {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0, // Scroll ke paling atas karena list di-reverse
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("FIDH - CHAT"),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            ),
            icon: const Icon(Icons.history),
            tooltip: "Riwayat",
          ),
          IconButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsyncValue.when(
                data: (messages) {
                  if (messages.isEmpty && !chatState.isLoading) {
                    return _buildEmptyState();
                  }
                  return _buildMessageList(
                      messages, chatState.streamingResponse);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('Terjadi Error: $err')),
              ),
            ),
            _buildTextInput(chatState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor.withAlpha(50),
              child: Icon(Icons.auto_awesome,
                  size: 40, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Mulai Percakapan',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tanyakan apa saja untuk memulai.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
      List<ChatMessage> messages, String streamingResponse) {
    if (messages.isEmpty && streamingResponse.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length + (streamingResponse.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && streamingResponse.isNotEmpty) {
          return BubbleChat(
            message: ChatMessage(
              text: streamingResponse,
              participant: ChatParticipant.model,
            ),
          );
        }
        final messageIndex = streamingResponse.isNotEmpty ? index - 1 : index;
        return BubbleChat(message: messages[messageIndex]);
      },
    );
  }

  Widget _buildTextInput(bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!,
                        height: 100, width: 100, fit: BoxFit.cover),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedImage = null),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.add_photo_alternate_outlined,
                    color: Colors.grey[400]),
                onPressed: isLoading ? null : _pickImage,
                tooltip: "Lampirkan Gambar",
              ),
              IconButton(
                icon: Icon(Icons.attach_file, color: Colors.grey[400]),
                onPressed: isLoading
                    ? null
                    : ref
                        .read(chatControllerProvider.notifier)
                        .pickAndUploadFile,
                tooltip: "Lampirkan File",
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: _speechToText.isListening
                        ? 'Mendengarkan...'
                        : "Tanyakan sesuatu...",
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onSubmitted: isLoading ? null : (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: Icon(_speechToText.isListening
                    ? Icons.mic_off
                    : Icons.mic_none_outlined),
                color: _speechToText.isListening
                    ? Colors.redAccent
                    : Colors.grey[400],
                onPressed: isLoading || !_speechEnabled
                    ? null
                    : (_speechToText.isNotListening
                        ? _startListening
                        : _stopListening),
                tooltip: "Input Suara",
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: Theme.of(context).primaryColor,
                onPressed: isLoading ? null : _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BubbleChat extends StatelessWidget {
  const BubbleChat({super.key, required this.message});
  final ChatMessage message;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Tidak bisa membuka $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.participant == ChatParticipant.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).primaryColor
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null && message.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.imageUrl!,
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (message.fileUrl != null && message.fileUrl!.isNotEmpty)
              InkWell(
                onTap: () => _launchUrl(message.fileUrl!),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.fileName ?? "File",
                          style: const TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
