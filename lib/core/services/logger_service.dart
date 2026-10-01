import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class LoggerService extends GetxService {
  void info(String message) {
    if (kDebugMode) {
      print('[INFO] [${DateTime.now().toIso8601String()}] $message');
    }
  }

  void warning(String message) {
    if (kDebugMode) {
      print('[WARN] [${DateTime.now().toIso8601String()}] $message');
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[ERROR] [${DateTime.now().toIso8601String()}] $message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
  }

  Future<LoggerService> init() async {
    return this;
  }
}
