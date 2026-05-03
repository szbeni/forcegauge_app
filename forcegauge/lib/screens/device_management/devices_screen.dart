import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:forcegauge/bloc/cubit/devicemanager_cubit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:forcegauge/screens/device_management/add_new_device_screen.dart';
import 'package:forcegauge/screens/device_management/device_list.dart';
import 'package:forcegauge/screens/device_management/discover_devices_screen.dart';
import 'package:forcegauge/screens/device_management/tindeq_scan_utils.dart';

class DevicesScreen extends StatefulWidget {
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final Map<String, ScanResult> _nearby = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  String? _scanMessage;
  bool _abortBle = false;

  @override
  void initState() {
    super.initState();
    if (_isHandheldTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bleScanLoop());
    }
  }

  static bool get _isHandheldTarget {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool _scanMessageShowsAppSettingsLink(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('permission') ||
        lower.contains('blocked') ||
        msg.contains('Open Settings');
  }

  Future<void> _bleScanLoop() async {
    while (mounted && !_abortBle) {
      final err = await TindeqScanUtils.blockingReasonBeforeScan();
      if (!mounted || _abortBle) return;

      if (err != null) {
        setState(() {
          _scanMessage = err;
          _scanning = false;
        });
        await Future.delayed(const Duration(seconds: 3));
        continue;
      }

      setState(() {
        _scanMessage = null;
        _scanning = true;
      });

      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        if (!mounted || _abortBle) return;
        var changed = false;
        for (final r in list) {
          if (!TindeqScanUtils.looksLikeProgressor(r)) continue;
          final id = r.device.remoteId.str;
          if (_nearby[id] != r) {
            _nearby[id] = r;
            changed = true;
          }
        }
        if (changed) setState(() {});
      });

      try {
        // `startScan` returns as soon as the scan is *started*; the timeout is applied
        // internally. Do not call `stopScan` immediately afterward — that races Android
        // registration (status=6, "could not find callback wrapper").
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 14),
        );
        await Future<void>.delayed(const Duration(seconds: 15));
      } catch (e) {
        if (mounted && !_abortBle) {
          setState(() => _scanMessage = 'Scan failed: $e');
        }
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }
      } finally {
        await _scanSub?.cancel();
        _scanSub = null;
      }

      if (!mounted || _abortBle) return;
      setState(() => _scanning = false);
      // Cooldown between sessions to avoid Android BLE scan throttling.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  List<ScanResult> _nearbyNotYetAdded(DevicemanagerState state) {
    final entries = _nearby.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return entries.where((r) {
      final url = 'tindeq://${r.device.remoteId.str}';
      return state.getDeviceByURL(url) == null;
    }).toList();
  }

  Future<void> _addTindeqDevice(BuildContext context, ScanResult r) async {
    final defaultName = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : 'Progressor');
    final controller = TextEditingController(text: defaultName);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Progressor'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Device name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !context.mounted) return;
    final url = 'tindeq://${r.device.remoteId.str}';
    context.read<DevicemanagerCubit>().addDevice(name, url);
  }

  @override
  void dispose() {
    _abortBle = true;
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Added Devices'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Discover Wi‑Fi devices',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiscoverDevicesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DevicemanagerCubit, DevicemanagerState>(
        builder: (context, dmState) {
          final candidates = _nearbyNotYetAdded(dmState);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isHandheldTarget) ...[
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bluetooth_searching,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nearby Progressor',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const Spacer(),
                            if (_scanning)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Wake the device (press its button). Unpaired is normal — tap a row to add.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_scanMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _scanMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                          if (_scanMessageShowsAppSettingsLink(_scanMessage!))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await openAppSettings();
                                },
                                icon: const Icon(Icons.settings, size: 18),
                                label: const Text('Open app settings'),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Text(
                      _scanning
                          ? 'Searching…'
                          : 'No new Progressor found yet. Keep Bluetooth on and the device awake.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = candidates[i];
                        final label = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : (r.advertisementData.advName.isNotEmpty
                                ? r.advertisementData.advName
                                : 'Progressor');
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.fitness_center, size: 22),
                          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('RSSI ${r.rssi} · ${r.device.remoteId.str}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _addTindeqDevice(context, r),
                        );
                      },
                    ),
                  ),
              ],
              Expanded(child: DeviceList()),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddNewDeviceScreen(),
            ),
          );
        },
        tooltip: 'Add Device',
        child: const Icon(Icons.add),
      ),
    );
  }
}
