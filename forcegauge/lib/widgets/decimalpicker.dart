import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';

class DecimalPickerDialog extends StatefulWidget {
  final double initialValue;
  final double min;
  final double max;
  double step = 1;
  int decimals = 1;
  double acceleration = 0.1;
  final EdgeInsets titlePadding;
  final Widget title;
  final Widget confirmWidget;
  final Widget cancelWidget;

  DecimalPickerDialog({
    required this.initialValue,
    required this.min,
    required this.max,
    required this.step,
    required this.decimals,
    required this.acceleration,
    required this.title,
    required this.titlePadding,
    required Widget confirmWidget,
    required Widget cancelWidget,
  })  : confirmWidget = confirmWidget ?? new Text('OK'),
        cancelWidget = cancelWidget ?? new Text('CANCEL');

  @override
  State<StatefulWidget> createState() => new _DecimalPickerDialogState(initialValue);
}

class _DecimalPickerDialogState extends State<DecimalPickerDialog> {
  late double value;

  _DecimalPickerDialogState(double initialValue) {
    value = initialValue;
  }

  static bool _isEmptyContainer(Widget w) =>
      w is Container && (w as Container).child == null;

  @override
  Widget build(BuildContext context) {
    return new AlertDialog(
      title: widget.title,
      titlePadding: widget.titlePadding,
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 200,
          child: SpinBox(
              min: widget.min,
              max: widget.max,
              value: value,
              decimals: widget.decimals,
              step: widget.step,
              acceleration: widget.acceleration,
              onChanged: (value) {
                this.setState(() {
                  this.value = value;
                });
              }),
        ),
      ]),
      actions: [
        new TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: _isEmptyContainer(widget.cancelWidget)
              ? Text('CANCEL')
              : widget.cancelWidget,
        ),
        new TextButton(
          onPressed: () => Navigator.of(context).pop(value),
          child: _isEmptyContainer(widget.confirmWidget)
              ? Text('OK')
              : widget.confirmWidget,
        ),
      ],
    );
  }
}
