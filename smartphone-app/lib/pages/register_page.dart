import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../boundaries/preferences_provider.dart' show UidStore;


/// Page to display the consent form and ask for device's ID.
class RegisterPage extends StatefulWidget {
  final VoidCallback next;
  final UidStore uidStore;

  @override
  _RegisterPageState createState() => _RegisterPageState();

  RegisterPage(this.uidStore, this.next);
}

class _RegisterPageState extends State<RegisterPage> {
  TextEditingController controller;
  FocusNode textFocusNode;
  double textScale = 1.0;
  double maxScale = 2.0;
  double minScale = 0.9;
  double defaultScale = 1.0;

  @override
  Widget build(BuildContext context) {
    var assets = DefaultAssetBundle.of(context);
    return Scaffold(
        appBar: AppBar(
            title: Text('Participation au projet de recherche'),
            actions: [
              IconButton(
                  icon: Icon(
                    Icons.zoom_in,
                    size: 30,
                  ),
                  onPressed: () => showDialog(
                      context: context,
                      builder: (context) => SimpleDialog(
                              title: const Text('Taille du texte'),
                              children: <Widget>[
                                ((textScale >= maxScale)
                                    ? Container()
                                    : SimpleDialogOption(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          setState(() => textScale =
                                              min(maxScale, textScale + 0.1));
                                        },
                                        child: Row(children: [
                                          Icon(Icons.zoom_in),
                                          const Text('Augmenter')
                                        ]),
                                      )),
                                ((textScale <= minScale)
                                    ? Container()
                                    : SimpleDialogOption(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          setState(() => textScale =
                                              max(minScale, textScale - 0.1));
                                        },
                                        child: Row(children: [
                                          Icon(Icons.zoom_out),
                                          const Text('Réduire')
                                        ]),
                                      )),
                                ((textScale == defaultScale)
                                    ? Container()
                                    : SimpleDialogOption(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          setState(
                                              () => textScale = defaultScale);
                                        },
                                        child: Row(children: [
                                          Icon(Icons.youtube_searched_for),
                                          const Text('Taille par défaut')
                                        ]),
                                      )),
                              ])))
            ]),
        body: Scrollbar(
            child: SingleChildScrollView(
          child: FutureBuilder(
              future: assets.loadString("assets/consent-form.md"),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Text('Chargement...')
                  );
                } else
                  return Container(
                    padding: EdgeInsets.all(16),
                    child: Column(children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: MarkdownBody(
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(Theme.of(context))
                                    .copyWith(textScaleFactor: textScale),
                            data: snapshot.data,
                          )),
                      Container(
                          padding: EdgeInsets.only(left: 10, right: 10),
                          child: TextField(
                              controller: controller,
                              focusNode: textFocusNode,
                              decoration: InputDecoration(
                                  labelText: 'Nom Prénom'))),
                      ButtonBar(children: [
                        RaisedButton(
                          child: Text("J'accepte"),
                          color: Colors.blue,
                          onPressed: () {
                                var text = controller.text;
                                if (text.isEmpty) {
                                  textFocusNode.requestFocus();
                                } else {
                                  widget.uidStore.setLocalUid(text);
                                  print('[RegisterPage] Local uid: $text');
                                  widget.next();
                                }
                          }
                        )
                      ])
                    ]),
                  );
              }),
        )));
  }

  void initState() {
    super.initState();
    controller = TextEditingController();
    textFocusNode = FocusNode();
  }

  void dispose() {
    super.dispose();
    controller.dispose();
    textFocusNode.dispose();
  }

  Widget welcomeText(context) {
    var assets = DefaultAssetBundle.of(context);
    return FutureBuilder(
      future: assets.loadString("assets/consent-form.md"),
      builder: (context, snapshot) => snapshot.hasData
          ? Align(
              alignment: Alignment.centerLeft,
              child: MarkdownBody(
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(textScaleFactor: textScale),
                data: snapshot.data,
              ))
          : Text("loading..."),
    );
  }
}