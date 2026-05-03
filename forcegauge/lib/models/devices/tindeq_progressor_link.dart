import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_link.dart';

/// Tindeq Progressor over BLE ([Progressor API](https://tindeq.com/progressor_api/)).
/// Official sample: `progressor_client.py` (UUIDs and opcodes).
class TindeqProgressorLink implements DeviceLink {
  /// Primary GATT service (filter BLE scan results).
  static final Guid serviceUuid = Guid('7e4e1701-1ea6-40c9-9dcc-13d34ffead57');
  static final Guid _dataCharUuid = Guid('7e4e1702-1ea6-40c9-9dcc-13d34ffead57');
  static final Guid _controlCharUuid = Guid('7e4e1703-1ea6-40c9-9dcc-13d34ffead57');

  static const int _cmdTareScale = 100;
  static const int _cmdStartWeightMeas = 101;
  static const int _cmdStopWeightMeas = 102;
  static const int _resWeightMeas = 1;

  String? _url;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _dataChar;
  BluetoothCharacteristic? _controlChar;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool _isConnected = false;
  bool _isConnecting = false;
  String _lastStatusMsg = '';
  DateTime? _lastMessageTime;
  int _timeoutMs = 5000;
  int _connectionCheckPeriodMs = 5000;
  Timer? _timer;

  int? _timeOriginUs;

  final ObserverList<Function> _listenersOnMessage = ObserverList<Function>();
  final ObserverList<Function> _listenersOnStatusChanged = ObserverList<Function>();

  TindeqProgressorLink() {
    _timer = Timer.periodic(
      Duration(milliseconds: _connectionCheckPeriodMs),
      _periodicConnectionCheck,
    );
  }

  void _newStatus(String statusMsg) {
    _lastStatusMsg = statusMsg;
    for (final cb in _listenersOnStatusChanged) {
      cb(statusMsg);
    }
  }

  String _remoteIdFromUrl(String url) {
    const prefix = 'tindeq://';
    if (!url.startsWith(prefix)) {
      throw ArgumentError('Expected tindeq:// URL, got: $url');
    }
    return url.substring(prefix.length);
  }

  @override
  void connect(dynamic url) {
    _url = url as String;
    reset();
    if (kIsWeb) {
      _newStatus('Tindeq Progressor requires Android or iOS (not web).');
      return;
    }
    _newStatus('Connecting to $_url');
    _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_url == null || kIsWeb) return;
    if (_isConnecting) return;
    _isConnecting = true;
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _newStatus('Bluetooth not supported on this device');
        _isConnecting = false;
        return;
      }
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        _newStatus('Bluetooth is off');
        _isConnecting = false;
        return;
      }

      final remoteId = _remoteIdFromUrl(_url!);
      _device = BluetoothDevice.fromId(remoteId);

      _connSub?.cancel();
      _connSub = _device!.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _notifySub?.cancel();
          _notifySub = null;
          _dataChar = null;
          _controlChar = null;
          _newStatus('Disconnected');
        }
      });

      await _device!.connect(license: License.free);
      await _device!.discoverServices();

      BluetoothCharacteristic? dataC;
      BluetoothCharacteristic? ctrlC;
      for (final svc in _device!.servicesList) {
        if (svc.uuid != serviceUuid) continue;
        for (final c in svc.characteristics) {
          if (c.characteristicUuid == _dataCharUuid) dataC = c;
          if (c.characteristicUuid == _controlCharUuid) ctrlC = c;
        }
      }

      if (dataC == null || ctrlC == null) {
        await _device!.disconnect();
        _newStatus('Progressor service not found on device');
        _isConnecting = false;
        return;
      }

      _dataChar = dataC;
      _controlChar = ctrlC;

      await _dataChar!.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = _dataChar!.onValueReceived.listen(_onData, onError: (e) {
        _newStatus('BLE notify error: $e');
      });

      await _controlChar!.write([_cmdStartWeightMeas], withoutResponse: false);

      _isConnected = true;
      _isConnecting = false;
      _lastMessageTime = DateTime.now();
      _timeOriginUs = null;
      _newStatus('Connected');
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _newStatus('Error: $e');
    }
  }

  void _onData(List<int> data) {
    _lastMessageTime = DateTime.now();
    if (!_isConnected) {
      _isConnected = true;
      _newStatus('Connected');
    }

    if (data.isEmpty) return;
    if (data[0] != _resWeightMeas) return;

    final samples = <Map<String, num>>[];
    for (var i = 2; i + 8 <= data.length; i += 8) {
      final bd = ByteData.sublistView(Uint8List.fromList(data), i, i + 8);
      final weightKg = bd.getFloat32(0, Endian.little);
      final tUs = bd.getUint32(4, Endian.little);
      _timeOriginUs ??= tUs;
      final timeSec = (tUs - _timeOriginUs!) / 1000000.0;
      samples.add({
        'time': timeSec,
        'raw': weightKg,
        'value': weightKg,
      });
    }

    if (samples.isEmpty) return;
    final msg = jsonEncode({'data': samples});
    for (final cb in _listenersOnMessage) {
      cb(msg);
    }
  }

  @override
  void send(String message) {
    if (message.startsWith('offset:')) {
      _writeControl([_cmdTareScale]);
    }
    // add_tabata / other Wi‑Fi commands: ignored for Progressor
  }

  Future<void> _writeControl(List<int> bytes) async {
    final c = _controlChar;
    final d = _device;
    if (c == null || d == null || !d.isConnected) return;
    try {
      await c.write(bytes, withoutResponse: false);
    } catch (e) {
      _newStatus('Write error: $e');
    }
  }

  @override
  void close() {
    _timer?.cancel();
    _timer = null;
    reset();
  }

  @override
  void reset() {
    _notifySub?.cancel();
    _notifySub = null;
    _connSub?.cancel();
    _connSub = null;

    final dev = _device;
    final ctrl = _controlChar;

    _device = null;
    _dataChar = null;
    _controlChar = null;
    _isConnected = false;
    _isConnecting = false;

    if (dev != null && dev.isConnected) {
      unawaited(_disconnectDevice(dev, ctrl));
    }
  }

  Future<void> _disconnectDevice(BluetoothDevice dev, BluetoothCharacteristic? ctrl) async {
    if (ctrl != null) {
      try {
        await ctrl.write([_cmdStopWeightMeas], withoutResponse: false);
      } catch (_) {}
    }
    try {
      await dev.disconnect();
    } catch (_) {}
  }

  @override
  bool isConnected() => _isConnected;

  @override
  String statusMsg() => _lastStatusMsg;

  @override
  void addOnMessageListener(Function callback) => _listenersOnMessage.add(callback);

  @override
  void removeOnMessageListener(Function callback) => _listenersOnMessage.remove(callback);

  @override
  void addOnStatusChangedListener(Function callback) => _listenersOnStatusChanged.add(callback);

  @override
  void removeOnStatusChangedListener(Function callback) => _listenersOnStatusChanged.remove(callback);

  void _periodicConnectionCheck(Timer _) {
    if (_url == null || kIsWeb) return;

    if (!_isConnected) {
      if (!_isConnecting) {
        _connectInternal();
      }
    } else {
      if (_lastMessageTime != null) {
        final diff = DateTime.now().difference(_lastMessageTime!);
        if (diff.inMilliseconds > _timeoutMs) {
          _isConnected = false;
          _newStatus('Timeout (no samples)');
          reset();
          _connectInternal();
        }
      }
    }
  }
}
