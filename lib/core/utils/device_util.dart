import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtil {
  static Future<String> getFingerprint() async {
    final info = DeviceInfoPlugin();
    String raw = '';

    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      raw = '${android.id}-${android.model}-${android.brand}';
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      raw = '${ios.identifierForVendor}-${ios.model}';
    } else {
      raw = 'windows-${Platform.operatingSystemVersion}';
    }

    final bytes  = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS)     return 'ios';
    return 'windows';
  }
}