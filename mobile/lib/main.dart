import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/secure_store.dart';
import 'core/server_checker.dart';
import 'features/backup/background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) await initBackgroundBackup();
  runApp(AlcoveApp(checker: ServerChecker(), store: SecureStore()));
}
