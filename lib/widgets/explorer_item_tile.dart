import 'package:flutter/material.dart';
import 'package:filesize/filesize.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../pages/explorer_page.dart' show ExplorerItem, ExplorerItemView;
import '../widgets/modes_view.dart' show ModeIcon;
import '../utils.dart' show StringExtension;

class ExplorerItemTile extends StatelessWidget {
  final ExplorerItem item;
  final checked;
  final onChanged;
  final asCheckbox;
  final title;
  final subtitle;
  final leading;
  final onTap;
  final onLongPress;

  ExplorerItemTile({
    this.item,
    this.asCheckbox,
    this.checked,
    this.onChanged,
    this.onTap,
    this.onLongPress,
  })
  : title = _makeTitle(item)
  , subtitle = _makeSubtitle(item)
  , leading = Icon(item.mode.iconData, size: 40)
  ;

  @override
  Widget build(BuildContext context) {
    if (asCheckbox) {
      return CheckboxListTile(
        title: title,
        secondary: leading,
        subtitle: subtitle,
        value: checked,
        onChanged: onChanged
      );
    } else {
      return ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: _trailing(context),
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }
  }

  Widget _trailing(BuildContext context) => null;
}

Widget _makeTitle(item) {
  return Text(_formatPeriod(item.start, item.end).capitalize());
}

Widget _makeSubtitle(ExplorerItem item) {
  return RichText(
    text: TextSpan(
      children: [
        WidgetSpan(
          child: Icon(Icons.access_time, size: 14),
        ),
        TextSpan(
            text: ' ' + item.formattedDuration + '    ',
            style: TextStyle(color: Colors.black)),
        WidgetSpan(
          child: Icon(Icons.computer, size: 14),
        ),
        TextSpan(
            text: ' ' + filesize(item.sizeOnDisk) + '    ',
            style: TextStyle(color: Colors.black)),
        WidgetSpan(
          child: Icon(Icons.location_on, size: 14),
        ),
        TextSpan(
            text: item.nbSensors.toString(),
            style: TextStyle(color: Colors.black)),
      ],
    ),
  );
}

String _formatPeriod(start, stop) {
  var day = DateFormat('EEE d MMMM', 'fr_FR');
  var time = DateFormat.jm('fr_FR');
  return day.format(start) +
      ' entre ' +
      time.format(start) +
      ' et ' +
      ((start == stop) ? '??' : time.format(stop));
}