import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forcegauge/bloc/cubit/device_cubit.dart';
import 'package:forcegauge/bloc/cubit/devicemanager_cubit.dart';
import 'package:forcegauge/bloc/cubit/settings_cubit.dart';
import 'package:forcegauge/screens/history_tab/historylist_screen.dart';
import 'package:forcegauge/screens/settings_screen.dart';
import 'package:forcegauge/screens/navigation_drawer.dart';
import 'package:forcegauge/screens/tabata_tab/tabatalist_screen.dart';
import 'min_max_tab/device_graphview.dart';
import 'package:udp/udp.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    DeviceGraphLists(),
    TabataListScreen(false),
    TabataListScreen(true),
    HistoryListScreen(),
  ];

  void startUDPServer() async {
    var receiver = await UDP.bind(Endpoint.any(port: Port(65123)));
    receiver.asStream().listen((datagram) {
      var str = String.fromCharCodes(datagram!.data);
      if (str == "forcegauge") {
        BlocProvider.of<DevicemanagerCubit>(context).addDevice("forcegauge", datagram!.address.address);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    startUDPServer();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavDrawer(),
      appBar: AppBar(
        title: Text('Force Gauge'),
        backgroundColor: BlocProvider.of<SettingsCubit>(context).settings.primarySwatch,
        actions: <Widget>[
        IconButton(
          icon: Icon(
            Icons.settings,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(),
              ),
            );
          },
          tooltip: 'Settings',
        )
      ],
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
          onTap: onTabTapped,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          //unselectedItemColor: BlocProvider.of<SettingsCubit>(context).settings.primarySwatch,
          //selectedItemColor: Colors.amber[800],
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'MinMax',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer),
              label: 'Tabata',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Taget',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assessment),
              label: 'History',
            ),
          ]),
    );
  }

  void onTabTapped(int index) {
    if (index == 0) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
    setState(() {
      _currentIndex = index;
    });
  }
}

class DeviceGraphLists extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicemanagerCubit, DevicemanagerState>(builder: (context, state) {
      List<Widget> deviceGraphViewList = [];
      for (var i = 0; i < state.devices.length; i++) {
        var deviceGraphView = BlocProvider<DeviceCubit>(
          key: UniqueKey(),
          create: (_) => DeviceCubit(state.devices[i]),
          child: new DeviceGraphView(),
        );

        deviceGraphViewList.add(deviceGraphView);
      }
      return SingleChildScrollView(
        child: Column(
          children: deviceGraphViewList,
        ),
      );
    });
  }
}
