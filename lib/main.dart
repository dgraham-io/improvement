import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  try {
    await storage.init();
  } on FileSystemException {
    // Stale lock files from a previous crash — close Hive and retry once.
    await Hive.close();
    await storage.init();
  }

  runApp(ImprovementApp(storage: storage));
}
