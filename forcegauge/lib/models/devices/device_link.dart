/// Abstraction shared by WebSocket (Forcegauge Wi‑Fi) and BLE (Tindeq Progressor) transports.
abstract class DeviceLink {
  void connect(dynamic url);

  void close();

  void reset();

  bool isConnected();

  String statusMsg();

  void send(String message);

  void addOnMessageListener(Function callback);

  void removeOnMessageListener(Function callback);

  void addOnStatusChangedListener(Function callback);

  void removeOnStatusChangedListener(Function callback);
}
