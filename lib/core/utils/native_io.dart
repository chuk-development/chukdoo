/// Native I/O utilities.
///
/// This file provides web-safe access to dart:io features via conditional imports.
/// On web, the stub is used. On native, the real dart:io implementation is used.
library;

export 'native_io_stub.dart' if (dart.library.io) 'native_io_native.dart';
