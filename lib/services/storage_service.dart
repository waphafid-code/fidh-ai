// lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fungsi untuk mengunggah file dan mengembalikan URL download-nya
  Future<String?> uploadFile(String chatId, File file) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // Membuat path yang unik untuk setiap file
      final fileName = file.path.split('/').last;
      final path = 'uploads/${user.uid}/$chatId/$fileName';

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint("Error saat mengunggah file: $e");
      return null;
    }
  }
}
