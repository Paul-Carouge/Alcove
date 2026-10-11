import 'package:flutter/material.dart';

import 'app.dart';
import 'core/secure_store.dart';
import 'core/server_checker.dart';

void main() {
  runApp(AlcoveApp(checker: ServerChecker(), store: SecureStore()));
}
