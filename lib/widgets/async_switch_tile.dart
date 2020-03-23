import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AsyncSwitchTile extends StatefulWidget {
  final title;
  final subtitle;
  final secondary;
  final getValue;
  final setValue;

  AsyncSwitchTile({
    this.title,
    this.subtitle,
    this.secondary,
    this.getValue,
    this.setValue
  });

  @override
  State<StatefulWidget> createState() => AsyncSwitchTileState();
}


class AsyncSwitchTileState extends State<AsyncSwitchTile> {
  bool loading = true;
  bool value;

  @override
  void initState() {
    super.initState();
    widget.getValue().then(updateUI);
  }

  void onSwitchChanged(bool switchValue) {
    setState(() => loading = true);
    widget.setValue(switchValue).then(updateUI);
  }

  void updateUI(bool newValue) {
     setState(() {
       loading = false;
       value = newValue;
     });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ListTile(
        title:widget.title,
        subtitle: widget.subtitle,
        leading: widget.secondary,
        trailing: SizedBox(
          width: 25,
          height: 25,
          child:SpinKitCircle(
              size: 25,
              color: Colors.blueGrey
          ),
        ),
      );
    } else {
      return SwitchListTile(
        title: widget.title,
        subtitle: widget.subtitle,
        secondary: widget.secondary,
        value: value,
        onChanged: onSwitchChanged,
      );
    }
  }
}
