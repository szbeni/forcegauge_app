import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:forcegauge/bloc/cubit/devicemanager_cubit.dart';
import '../../bloc/cubit/tabatamanager_cubit.dart';
import '../../models/devices/device.dart';
import '../../models/tabata/tabata.dart';

class DeviceSettingsScreen extends StatefulWidget {
  Device device;
  DeviceSettingsScreen(this.device);
  @override
  _DeviceSettingsScreenState createState() => _DeviceSettingsScreenState();
}

enum updateState { init, updating, error, success }

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  updateState state = updateState.init;

  //TODO: check current version and firmware version before

  Future<bool> updateFirmware() async {
    return await widget.device.updateFirmware();
  }

  // If Button State is init : show Normal submit button
  Widget updateFirmwareButton() {
    if (state == updateState.init) {
      return ElevatedButton(
        //style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
        onPressed: () async {
          setState(() {
            state = updateState.updating;
          });
          var success = await updateFirmware();

          setState(() {
            if (success)
              state = updateState.success;
            else
              state = updateState.error;
          });
          // await Future.delayed(Duration(seconds: 2));
          // setState(() {
          //   state = updateState.init;
          // });
        },
        child: const Text('Update Firmware'),
      );
    } else if (state == updateState.updating) {
      return SizedBox(height: 50, width: 50, child: CircularProgressIndicator());
    } else if (state == updateState.success) {
      return Icon(
        Icons.done,
        size: 50,
        color: Colors.green,
      );
    } else if (state == updateState.error) {
      return Icon(
        Icons.cancel,
        size: 50,
        color: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = state == updateState.success;

    return new Scaffold(
        appBar: new AppBar(title: new Text('Device settings')),
        floatingActionButton: new FloatingActionButton(
            onPressed: () {
              // if (deviceName.length > 0 && deviceUrl.length > 0) {
              //   BlocProvider.of<DevicemanagerCubit>(context).addDevice(deviceName, deviceUrl);
              // }
              Navigator.of(context).pop();
            },
            tooltip: 'Save',
            child: new Icon(Icons.save)),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10),
            Align(
              alignment: Alignment.center,
              child: Text(
                this.widget.device.name,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              alignment: Alignment.center,
              child: new ElevatedButton(
                  onPressed: () async {
                    //TODO: move this somewhere sensible place
                    var tabatasString = await widget.device.getTabatas();
                    var tabatasJson = jsonDecode(tabatasString) as List;
                    List<Tabata> TabataList = [];
                    for (var tabataJson in tabatasJson) {
                      var newTabata = new Tabata.fromJson(tabataJson);
                      BlocProvider.of<TabatamanagerCubit>(context).addTabata(newTabata);
                    }
                  },
                  child: Text("Get tabatas")),
            ),
            Container(
              padding: EdgeInsets.all(10),
              alignment: Alignment.center,
              child: new ElevatedButton(
                  onPressed: () {
                    var tabatas = BlocProvider.of<TabatamanagerCubit>(context).getTabtas();
                    this.widget.device.sendTabatas(tabatas);
                  },
                  child: Text("Send tabatas")),
            ),
            // new ElevatedButton(
            //     onPressed: () async {
            //       bool success = await updateFirmware();

            //       ScaffoldMessenger.of(context).showSnackBar(
            //         SnackBar(
            //           content: new Text(success ? "Update successful." : "Update failed"),
            //           // action: SnackBarAction(
            //           //   label: 'Action',
            //           //   onPressed: () {
            //           //     // Code to execute.
            //           //   },
            //           // ),
            //         ),
            //       );

            //       //var tabatas = BlocProvider.of<TabatamanagerCubit>(context).getTabtas();
            //       //this.widget.device.sendTabatas(tabatas);
            //     },
            //     child: Text("Update Firmware")),
            Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(10),
              child: updateFirmwareButton(),
            ),
            Container(
              padding: EdgeInsets.all(10),
              alignment: Alignment.center,
              child: new ElevatedButton(
                  onPressed: () {
                    BlocProvider.of<DevicemanagerCubit>(context).removeDevice(widget.device.name);
                    Navigator.of(context).pop();
                    //var tabatas = BlocProvider.of<TabatamanagerCubit>(context).getTabtas();
                    //this.widget.device.sendTabatas(tabatas);
                  },
                  child: Text("Remove device")),
            ),

            // Container(
            //   height: 70,
            //   width: MediaQuery.of(context).size.width,
            //   alignment: Alignment.center,
            //   child: ElevatedButton(
            //     style: ElevatedButton.styleFrom(shape: StadiumBorder()),
            //     onPressed: () async {
            //       setState(() {
            //         isUpdating = true;
            //       });
            //       await Future.delayed(const Duration(seconds: 5));
            //       setState(() {
            //         isUpdating = false;
            //       });
            //     },
            //     child: (isUpdating)
            //         ? const SizedBox(
            //             width: 16,
            //             height: 16,
            //             child: CircularProgressIndicator(
            //               color: Colors.white,
            //               strokeWidth: 1.5,
            //             ))
            //         : const Text('Submit'),
            //   ),
            // ),

            // new TextField(
            //   autofocus: true,
            //   decoration: new InputDecoration(hintText: 'My Awsome Device', contentPadding: const EdgeInsets.all(16.0)),
            // ),
            // new TextField(
            //   autofocus: false,
            //   onChanged: (url) {
            //     deviceUrl = url;
            //   },
            //   decoration: new InputDecoration(
            //       hintText: 'Enter device URL. ex.: ws://192.168.4.1:81', contentPadding: const EdgeInsets.all(16.0)),
            // )
          ],
        ));
  }
}
