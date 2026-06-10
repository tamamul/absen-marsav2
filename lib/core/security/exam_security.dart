import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ExamSecurity {
  static const MethodChannel _channel =
      MethodChannel('com.marsa9.cbt/security');

  static Function(String type)? onViolationDetected;

  static bool _isInitialized = false;

  static Future<void> enable() async {
    // biar gak dobel init (ini sumber bug paling sering)
    if (_isInitialized) return;
    _isInitialized = true;

    await WakelockPlus.enable();

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    try {
      await _channel.invokeMethod('enableSecureFlag');
    } catch (_) {}

    // set handler sekali saja
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static Future<void> disable() async {
    _isInitialized = false;

    await WakelockPlus.disable();

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _channel.setMethodCallHandler(null);

    try {
      await _channel.invokeMethod('disableSecureFlag');
    } catch (_) {}
  }

  static Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'multiWindowDetected':
      case 'pipDetected':
        onViolationDetected?.call('app_switch');
        break;

      case 'userLeaveDetected':
        onViolationDetected?.call('focus_loss');

        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
        break;
    }
  }
}