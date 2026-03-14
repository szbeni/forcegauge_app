import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';

class NumberPickerDialog extends StatefulWidget {
  final int initialValue;
  final int min;
  final int max;
  final int step;
  final EdgeInsets titlePadding;
  final Widget title;
  final Widget confirmWidget;
  final Widget cancelWidget;

  NumberPickerDialog({
    required this.initialValue,
    required this.min,
    required this.max,
    required this.step,
    required this.title,
    required this.titlePadding,
    required Widget confirmWidget,
    required Widget cancelWidget,
  })  : confirmWidget = confirmWidget ?? new Text('OK'),
        cancelWidget = cancelWidget ?? new Text('CANCEL');

  @override
  State<StatefulWidget> createState() => new _NumberPickerDialogState(initialValue);
}

class _NumberPickerDialogState extends State<NumberPickerDialog> {
  late int value;

  _NumberPickerDialogState(int initialValue) {
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
        NumberPicker(
          //listViewWidth: 65,
          //initialValue: minutes,
          minValue: widget.min,
          maxValue: widget.max,
          step: widget.step,
          value: value,
          zeroPad: true,
          onChanged: (value) {
            this.setState(() {
              this.value = value;
            });
          },
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
