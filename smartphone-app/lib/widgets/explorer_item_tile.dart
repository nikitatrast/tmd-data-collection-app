import 'package:flutter/material.dart';
import 'package:filesize/filesize.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../backends/upload_manager.dart' show UploadStatus;
import '../pages/explorer_page.dart' show ExplorerItem, ExplorerItemView;
import '../widgets/modes_view.dart' show ModeIcon;
import '../widgets/upload_status_view.dart';
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
  final onUpload;
  final onCancelUpload;

  ExplorerItemTile({
    this.item,
    this.asCheckbox,
    this.checked,
    this.onChanged,
    this.onTap,
    this.onLongPress,
    this.onUpload,
    this.onCancelUpload,
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

  Widget _trailing(BuildContext context) =>
      ChangeNotifierProvider.value(
          value:item.status,
          child: Consumer<ValueNotifier<UploadStatus>>(
              builder: (context, _, __) => _makeTrailing(context)
          )
      );

  IconButton _makeTrailing(BuildContext context) {
    var action;
    if (item.status.value == UploadStatus.local) {
      action = onUpload;
    } else {
      action = onCancelUpload;
    }

    var i = item.status.value.iconData;
    return IconButton(
      icon: Opacity(opacity: 0.6, child: Icon(item.status.value.iconData, size: 30)),
      color: item.status.value.iconColor,
      onPressed: action,
    );
  }
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