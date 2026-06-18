/// Stub implementation for web where dart:io is not available.
library;

Future<String> readFileAsString(String path) async {
  throw UnsupportedError('File I/O is not supported on web');
}

Future<void> writeFileAsString(String path, String content) async {
  throw UnsupportedError('File I/O is not supported on web');
}

bool fileExists(String path) {
  return false;
}

String getResolvedExecutable() {
  return '';
}

Never exitApp(int code) {
  throw UnsupportedError('exit() is not supported on web');
}
