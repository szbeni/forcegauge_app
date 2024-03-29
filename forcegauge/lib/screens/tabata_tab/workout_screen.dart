import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forcegauge/bloc/cubit/device_cubit.dart';
import 'package:forcegauge/bloc/cubit/devicemanager_cubit.dart';
import 'package:forcegauge/bloc/cubit/reportmanager_cubit.dart';
import 'package:forcegauge/bloc/cubit/settings_cubit.dart';
import 'package:forcegauge/misc/format_time.dart';
import 'package:forcegauge/models/tabata/report.dart';
import 'package:forcegauge/models/tabata/tabata.dart';
import 'package:forcegauge/models/tabata/workout.dart';
import 'package:forcegauge/screens/history_tab/report_screen.dart';
import 'package:forcegauge/screens/min_max_tab/realtime_chart.dart';
import 'package:forcegauge/screens/tabata_tab/report_graph.dart';
import 'package:wakelock/wakelock.dart';

class WorkoutScreen extends StatefulWidget {
  final double targetForce;
  final Tabata tabata;

  WorkoutScreen({this.tabata, this.targetForce = 0});

  @override
  State<StatefulWidget> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool totalTimeDisplay = true;
  Workout _workout;

  @override
  initState() {
    super.initState();
    var tabataSounds = BlocProvider.of<SettingsCubit>(context).settings.tabataSounds;
    var mute = BlocProvider.of<SettingsCubit>(context).settings.silentMode;
    _workout = Workout(widget.tabata, tabataSounds, widget.targetForce, this._onWorkoutChanged, mute);
    _start();
  }

  @override
  dispose() {
    _workout.dispose();
    //try {
    //Screen.keepOn(false);
    Wakelock.disable();
    //} catch (e) {}

    super.dispose();
  }

  _onWorkoutChanged() {
    if (_workout.step == WorkoutState.finished) {
      Navigator.of(context).pop();
      BlocProvider.of<ReportmanagerCubit>(context).addWorkoutReport(_workout.workoutReport);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReportScreen(_workout.workoutReport),
        ),
      );

      //try {
      Wakelock.enable();
      //Screen.keepOn(false);
      //} catch (e) {}
    }
    this.setState(() {});
  }

  _getBackgroundColor(ThemeData theme) {
    switch (_workout.step) {
      case WorkoutState.exercising:
        return Colors.red;
      case WorkoutState.starting:
      case WorkoutState.finished:
        return Colors.green;
      case WorkoutState.resting:
        return Colors.lightBlue;
      case WorkoutState.breaking:
        return Colors.blue;
      default:
        return theme.scaffoldBackgroundColor;
    }
  }

  _pause() {
    _workout.pause();
    //try {
    //Wakelock.disable();
    //Screen.keepOn(false);
    //} catch (e) {}
  }

  _start() {
    _workout.start();
    //try {
    Wakelock.enable();
    //Screen.keepOn(true);
    //} catch (e) {}
  }

  Widget makeReportView(Map<String, ReportValues> reports) {
    var table = Table(border: TableBorder.all(), // Allows to add a border decoration around your table
        children: [
          TableRow(children: [
            Text('Workout', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Min', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Max', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Average', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Graph', style: TextStyle(fontWeight: FontWeight.bold)),
            //TextButton(onPressed: onPressed, child: Text("+"));
          ]),
        ]);
    for (var report in reports.keys) {
      var reportWidget = TableRow(children: [
        Text(report),
        Text(reports[report].getMin().toStringAsFixed(1)),
        Text(reports[report].getMax().toStringAsFixed(1)),
        Text(reports[report].getAverage().toStringAsFixed(1)),
        IconButton(
            icon: Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  //builder: (context) => Container(),
                  builder: (context) => ReportGraph(reports[report]),
                ),
              );
            })
      ]);
      table.children.add(reportWidget);
    }

    return table;
  }

  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var lightTextColor = theme.textTheme.bodyText2.color.withOpacity(0.8);

    var graphWidget = BlocBuilder<DevicemanagerCubit, DevicemanagerState>(builder: (context, state) {
      //TODO: fix this if device is lost
      int connectedDeviceNum = -1;
      //Select the first connected device to use as force value
      if (!(state is DevicemanagerInitial) && state.devices.length > 0) {
        for (int i = 0; i < state.devices.length; i++) {
          if (state.devices[i].isConnected()) {
            connectedDeviceNum = i;
            break;
          }
        }
      }

      if (connectedDeviceNum != -1) {
        return BlocProvider<DeviceCubit>(
          create: (_) => DeviceCubit(state.devices[connectedDeviceNum]),
          child: BlocBuilder<DeviceCubit, DeviceState>(builder: (context, state) {
            if (_workout.step == WorkoutState.exercising) {
              return Container(width: 200, child: EvenMoreRealtime(true, widget.targetForce));
              //return Container();
            } else {
              var lastReport = _workout.workoutReport.getSetRepReport(_workout.set, _workout.rep);
              if (lastReport != null) {
                return Container(width: 200, child: ReportGraph(lastReport));
                //return Container();
              } else {
                return Container();
                //return Text(state.device.lastValue.toStringAsFixed(1), style: TextStyle(fontSize: 40.0));
              }
            }
          }),
        );
      } else {
        return Text("");
      }
    });

    var forceTextStyle = TextStyle(fontSize: 80.0);
    var forceTextBox = BlocBuilder<DevicemanagerCubit, DevicemanagerState>(builder: (context, state) {
      //TODO: fix this if device is lost, remove code duplication
      int connectedDeviceNum = -1;
      //Select the first connected device to use as force value
      if (!(state is DevicemanagerInitial) && state.devices.length > 0) {
        for (int i = 0; i < state.devices.length; i++) {
          if (state.devices[i].isConnected()) {
            connectedDeviceNum = i;
            break;
          }
        }
      }

      if (connectedDeviceNum != -1) {
        return new BlocProvider<DeviceCubit>(
          create: (_) => DeviceCubit(state.devices[connectedDeviceNum]),
          child: BlocBuilder<DeviceCubit, DeviceState>(builder: (context, state) {
            _workout.newForceValue(state.device.lastValue.abs());
            return Text(state.device.lastValue.toStringAsFixed(1), style: forceTextStyle);
          }),
        );
      } else {
        return Text("", style: forceTextStyle);
      }
    });

    var tabataScreen;
    if (_workout.step == WorkoutState.finished) {
      return Container();
    } else {
      String timeDisplayText = 'Total Time';
      String timeDisplay = formatTime(_workout.totalTime);
      if (!totalTimeDisplay) {
        timeDisplayText = "Time Left";
        timeDisplay = formatTime(_workout.getTimeRemaning());
      }
      tabataScreen = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [graphWidget],
            ),
          ),
          Divider(height: 1, color: lightTextColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Text(Workout.stepName(_workout.step), style: TextStyle(fontSize: 60.0))],
          ),
          Divider(height: 1, color: lightTextColor),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [forceTextBox]),
          Divider(height: 1, color: lightTextColor),
          Container(width: MediaQuery.of(context).size.width, child: FittedBox(child: Text(formatTime(_workout.timeLeft)))),
          Divider(height: 1, color: lightTextColor),
          Table(columnWidths: {
            0: FlexColumnWidth(0.5),
            1: FlexColumnWidth(0.5),
            2: FlexColumnWidth(1.0)
          }, children: [
            TableRow(children: [
              TableCell(child: Text('Set', style: TextStyle(fontSize: 30.0))),
              TableCell(child: Text('Rep', style: TextStyle(fontSize: 30.0))),
              TableCell(child: Text(timeDisplayText, textAlign: TextAlign.end, style: TextStyle(fontSize: 30.0)))
            ]),
            TableRow(children: [
              TableCell(
                child: Text('${_workout.set}', style: TextStyle(fontSize: 60.0)),
              ),
              TableCell(
                child: Text('${_workout.rep}', style: TextStyle(fontSize: 60.0)),
              ),
              TableCell(
                  child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, primary: Colors.black),
                      onPressed: () {
                        setState(() {
                          totalTimeDisplay = !totalTimeDisplay;
                        });
                      },
                      child: Text(
                        timeDisplay,
                        style: TextStyle(fontSize: 60.0),
                        textAlign: TextAlign.right,
                      )))
            ]),
          ]),
          Divider(height: 1, color: lightTextColor),
          _buildButtonBar(),
        ],
      );
    }

    return Scaffold(
      body: Container(
        color: _getBackgroundColor(theme),
        padding: EdgeInsets.symmetric(horizontal: 15),
        child: tabataScreen,
      ),
    );
  }

  Widget _buildButtonBar() {
    if (_workout.step == WorkoutState.finished) {
      return Container();
    }
    double iconSize = 50;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous),
          onPressed: () {
            _workout.previous();
            _onWorkoutChanged();
          },
          iconSize: iconSize,
        ),
        IconButton(
          icon: Icon(_workout.isActive ? Icons.pause : Icons.play_arrow),
          onPressed: _workout.isActive ? _pause : _start,
          iconSize: iconSize,
        ),
        IconButton(
            icon: Icon(Icons.stop),
            iconSize: iconSize,
            onPressed: () {
              _workout.finished();
            }),
        IconButton(
          icon: Icon(Icons.skip_next),
          onPressed: () {
            _workout.next();
            _onWorkoutChanged();
          },
          iconSize: iconSize,
        ),
        IconButton(
          icon: Icon(_workout.isMuted() ? Icons.music_off : Icons.music_note),
          onPressed: () {
            this._workout.mute(!this._workout.isMuted());
            _onWorkoutChanged();
          },
          iconSize: iconSize,
        ),
      ],
    );
  }
}
