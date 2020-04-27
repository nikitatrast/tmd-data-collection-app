import 'package:flutter/material.dart';
import 'package:filesize/filesize.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../backends/upload_manager.dart' show UploadStatus;
import '../pages/explorer_page.dart' show ExplorerItem;
import '../widgets/modes_view.dart' show ModeIcon;
import '../widgets/upload_status_view.dart';
import '../utils.dart' show StringExtension;

/// [ListTile] to interact with an [ExplorerItem] instance.
class ExplorerItemTile extends StatelessWidget {
  /// [ExplorerItem] to display.
  final ExplorerItem item;

  /// Whether this tile is initially marked as checked.
  final checked;

  /// Callback when [checked] changes.
  final void Function(bool) onChanged;

  /// Whether to display this tile with a trailing [Checkbox].
  final asCheckbox;

  /// This tile's title.
  final title;

  /// This tile's subtitles.
  final subtitle;

  /// Leading icon to be displayed before this tile's [title].
  final Icon leading;

  /// Callback when this tile is tapped.
  final void Function() onTap;


  /// Callback when this tile is pressed.
  final void Function() onLongPress;

  /// Callback when user taps the upload icon.
  final void Function() onUpload;

  /// Callback when user taps the cancel upload icon.
  final void Function() onCancelUpload;

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

  /// Builds this tile's trailing widget
  Widget _trailing(BuildContext context) =>
      ChangeNotifierProvider.value(
          value:item.status,
          child: Consumer<ValueNotifier<UploadStatus>>(
              builder: (context, _, __) => _uploadStatusIconButton(context)
          )
      );

  /// Builds an [IconButton] to upload or cancel upload of this [item].
  IconButton _uploadStatusIconButton(BuildContext context) {
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