/// Native implementation using dart:io.
library;

import 'dart:io';

Future<String> readFileAsString(String path) async {
  return File(path).readAsString();
}

Future<void> writeFileAsString(String path, String content) async {
  await File(path).writeAsString(content);
}

bool fileExists(String path) {
  return File(path).existsSync();
}

String getResolvedExecutable() {
  return Platform.resolvedExecutable;
}

Never exitApp(int code) {
  exit(code);
}
