import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Types of errors that can occur in the app
enum ErrorType {
  sync,
  encryption,
  network,
  storage,
  general,
}

/// State representing an app-wide error
class AppErrorState {
  final bool hasError;
  final ErrorType? errorType;
  final String? message;
  final bool canRetry;
  final DateTime? timestamp;

  const AppErrorState({
    this.hasError = false,
    this.errorType,
    this.message,
    this.canRetry = false,
    this.timestamp,
  });

  AppErrorState copyWith({
    bool? hasError,
    ErrorType? errorType,
    String? message,
    bool? canRetry,
    DateTime? timestamp,
    bool clearError = false,
  }) {
    if (clearError) {
      return const AppErrorState();
    }
    return AppErrorState(
      hasError: hasError ?? this.hasError,
      errorType: errorType ?? this.errorType,
      message: message ?? this.message,
      canRetry: canRetry ?? this.canRetry,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Get user-friendly error title
  String get title {
    switch (errorType) {
      case ErrorType.sync:
        return 'Sync-Fehler';
      case ErrorType.encryption:
        return 'Verschlüsselungs-Fehler';
      case ErrorType.network:
        return 'Netzwerk-Fehler';
      case ErrorType.storage:
        return 'Speicher-Fehler';
      case ErrorType.general:
      case null:
        return 'Fehler';
    }
  }

  /// Get user-friendly error description
  String get description {
    if (message != null) return message!;
    switch (errorType) {
      case ErrorType.sync:
        return 'Die Synchronisierung ist fehlgeschlagen.';
      case ErrorType.encryption:
        return 'Es gab ein Problem mit der Verschlüsselung.';
      case ErrorType.network:
        return 'Keine Internetverbindung.';
      case ErrorType.storage:
        return 'Daten konnten nicht gespeichert werden.';
      case ErrorType.general:
      case null:
        return 'Ein unerwarteter Fehler ist aufgetreten.';
    }
  }
}

/// Notifier for managing app-wide errors
class ErrorNotifier extends StateNotifier<AppErrorState> {
  ErrorNotifier() : super(const AppErrorState());

  /// Show an error with optional retry capability
  void showError({
    required ErrorType type,
    String? message,
    bool canRetry = false,
  }) {
    state = AppErrorState(
      hasError: true,
      errorType: type,
      message: message,
      canRetry: canRetry,
      timestamp: DateTime.now(),
    );
  }

  /// Show a sync error
  void showSyncError([String? message]) {
    showError(
      type: ErrorType.sync,
      message: message,
      canRetry: true,
    );
  }

  /// Show a network error
  void showNetworkError([String? message]) {
    showError(
      type: ErrorType.network,
      message: message ?? 'Keine Internetverbindung.',
      canRetry: true,
    );
  }

  /// Show an encryption error
  void showEncryptionError([String? message]) {
    showError(
      type: ErrorType.encryption,
      message: message,
      canRetry: false,
    );
  }

  /// Show a storage error
  void showStorageError([String? message]) {
    showError(
      type: ErrorType.storage,
      message: message,
      canRetry: true,
    );
  }

  /// Clear the current error
  void clearError() {
    state = const AppErrorState();
  }

  /// Auto-clear error after a delay
  void autoClear({Duration duration = const Duration(seconds: 5)}) {
    Future.delayed(duration, () {
      if (mounted) {
        clearError();
      }
    });
  }
}

/// Provider for app-wide error state
final errorProvider = StateNotifierProvider<ErrorNotifier, AppErrorState>((ref) {
  return ErrorNotifier();
});
