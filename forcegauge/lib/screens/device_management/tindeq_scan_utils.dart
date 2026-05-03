import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:forcegauge/models/devices/tindeq_progressor_link.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helpers for scanning [Tindeq Progressor](https://tindeq.com/progressor_api/) devices.
class TindeqScanUtils {
  TindeqScanUtils._();

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool looksLikeProgressor(ScanResult r) {
    final platformName = r.device.platformName;
    if (platformName.isNotEmpty && platformName.startsWith('Progressor')) {
      return true;
    }
    final advName = r.advertisementData.advName;
    if (advName.isNotEmpty && advName.startsWith('Progressor')) {
      return true;
    }
    return r.advertisementData.serviceUuids.contains(TindeqProgressorLink.serviceUuid);
  }

  /// Requests OS Bluetooth permissions, then validates adapter.  
  /// Returns `null` if scanning is allowed; otherwise a short user-facing message.
  static Future<String?> blockingReasonBeforeScan() async {
    if (kIsWeb) {
      return 'Bluetooth is not available in the web build.';
    }
    if (!(defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS)) {
      return 'Tindeq devices use Bluetooth — open this screen on a phone or tablet.';
    }

    if (_isAndroid) {
      // Android 12+ (API 31): BLUETOOTH_SCAN / BLUETOOTH_CONNECT — these show the system dialogs.
      // `Permission.bluetooth` on Android does not prompt (always allowed in permission_handler).
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final scan = statuses[Permission.bluetoothScan]!;
      final connect = statuses[Permission.bluetoothConnect]!;

      if (!scan.isGranted || !connect.isGranted) {
        if (scan.isPermanentlyDenied || connect.isPermanentlyDenied) {
          return 'Bluetooth is blocked for this app. Tap “App settings” below and enable '
              'Nearby devices / Bluetooth permissions.';
        }
        return 'Bluetooth permission is needed to find Progressor devices.';
      }

      // Older Android stacks may still use location for BLE discovery.
      await Permission.locationWhenInUse.request();
    } else if (_isIos) {
      // iOS: prompts for Core Bluetooth when needed.
      final bt = await Permission.bluetooth.request();
      if (!bt.isGranted) {
        if (bt.isPermanentlyDenied) {
          return 'Bluetooth is blocked for this app. Open Settings → Forcegauge and enable Bluetooth.';
        }
        return 'Bluetooth permission is needed to find Progressor devices.';
      }
    }

    if (await FlutterBluePlus.isSupported == false) {
      return 'This device does not support Bluetooth LE.';
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      return 'Turn Bluetooth on to discover nearby Progressors.';
    }

    return null;
  }
}
