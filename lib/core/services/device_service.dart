import 'package:flutter/services.dart';

class DeviceService {
  static const MethodChannel _channel = MethodChannel('com.ansorstudi.drinkpos_lite/device');

  static Future<void> openWhatsApp({String phone = '081775700114', String? message}) async {
    try {
      await _channel.invokeMethod('openWhatsApp', {
        'phone': phone,
        if (message != null) 'message': message,
      });
    } catch (_) {}
  }

  static Future<void> openBluetoothSettings() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } catch (_) {}
  }

  static Future<String?> getIncomingPackagePath() async {
    try {
      final res = await _channel.invokeMethod<String>('getIncomingPackagePath');
      return res;
    } catch (_) {
      return null;
    }
  }

  static Future<void> exitApp() async {
    await SystemNavigator.pop();
  }
}
