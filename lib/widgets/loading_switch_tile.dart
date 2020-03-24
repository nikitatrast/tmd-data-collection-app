import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoadingSwitchTile<T extends ValueNotifier> extends StatelessWidget {
  final title;
  final subtitle;
  final secondary;

  LoadingSwitchTile({
    this.title,
    this.subtitle,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      builder: (context, notifier, _) {
        if (notifier.value == null) {
          return ListTile(
            title:this.title,
            subtitle: this.subtitle,
            leading: this.secondary,
            trailing: SizedBox(
                width: 25,
                height: 25,
                child:CircularProgressIndicator()
            ),
          );
        } else {
          return SwitchListTile(
            title: this.title,
            subtitle: this.subtitle,
            secondary: this.secondary,
            value: notifier.value,
            onChanged: (value) => notifier.value = value,
          );
        }
      }
    );
  }
}
