import 'package:flutter/material.dart';
import 'package:forcegauge/models/tabata/tabata.dart';

class Settings {
  static var soundFiles = {
    'None': '',
    'Low Beep': 'pip.mp3',
    'High Beep': 'boop.mp3',
    'Ding Ding Ding!': 'dingdingding.mp3',
    'Woop Woop': 'woopwoop.mp3',
    'Whistle': 'whistle.mp3',
    'Whistle 2': 'whistle2.mp3',
    'Double Whistle': 'doublewhistle.mp3',
    'Metal Ding': 'metalding.mp3',
    'Gong': 'gong.mp3',
    'Gong 2': 'gong2.mp3',
    'Doorbell': 'doorbell.mp3'
  };
  late bool nightMode;
  late bool silentMode;
  late MaterialColor primarySwatch;
  late double fontSize;
  late double targetForce;
  TabataSounds tabataSounds = new TabataSounds();

  fromJson(Map<String, dynamic> json) {
    fontSize = json['fontSize'] ?? 120;
    nightMode = json['nightMode'] ?? false;
    silentMode = json['silentMode'] ?? false;
    targetForce = json['targetForce'] ?? 30;
    final index = json['primarySwatch'];
    final i = (index is int && index >= 0 && index < Colors.primaries.length)
        ? index
        : Colors.primaries.indexOf(Colors.blue);
    primarySwatch = Colors.primaries[i];
    tabataSounds.countdownPip = json['countdownPip'] ?? 'pip.mp3';
    tabataSounds.startRep = json['startRep'] ?? 'whistle.mp3';
    tabataSounds.startRest = json['startRest'] ?? 'metalding.mp3';
    tabataSounds.startBreak = json['startBreak'] ?? 'dingdingding.mp3';
    tabataSounds.startSet = json['startSet'] ?? 'whistle.mp3';
    tabataSounds.endWorkout = json['endWorkout'] ?? 'dingdingding.mp3';
    tabataSounds.warningBeforeBreakEnds = json['warningBeforeBreakEnds'] ?? 'woopwoop.mp3';
    tabataSounds.targetReached = json['targetReached'] ?? 'doublewhistle.mp3';
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'targetForce': targetForce,
        'nightMode': nightMode,
        'silentMode': silentMode,
        'primarySwatch': Colors.primaries.indexOf(primarySwatch),
        'countdownPip': tabataSounds.countdownPip,
        'startRep': tabataSounds.startRep,
        'startRest': tabataSounds.startRest,
        'startBreak': tabataSounds.startBreak,
        'startSet': tabataSounds.startSet,
        'endWorkout': tabataSounds.endWorkout,
        'warningBeforeBreakEnds': tabataSounds.warningBeforeBreakEnds,
        'targetReached': tabataSounds.targetReached,
      };
}
