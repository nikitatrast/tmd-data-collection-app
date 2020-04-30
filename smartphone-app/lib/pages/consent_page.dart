import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ConsentPage extends StatefulWidget {
  @override
  _ConsentPageState createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  TextEditingController controller;
  double textScale = 1.0;
  double maxScale = 2.0;
  double minScale = 0.9;
  double defaultScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Notice d\'information'),
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
                            ((textScale >= maxScale) ? Container() : SimpleDialogOption(
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(() => textScale = min(maxScale, textScale + 0.1));
                              },
                              child: Row (children: [
                                Icon(Icons.zoom_in),
                                const Text('Augmenter')
                              ]),
                            )),
                            ((textScale <= minScale) ? Container() : SimpleDialogOption(
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(() => textScale = max(minScale, textScale - 0.1));
                              },
                              child: Row (children: [
                                Icon(Icons.zoom_out),
                                const Text('Réduire')
                              ]),
                            )),
                            ((textScale == defaultScale) ? Container() : SimpleDialogOption(
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(() => textScale = defaultScale);
                              },
                              child: Row (children: [
                                Icon(Icons.youtube_searched_for),
                                const Text('Taille par défaut')
                              ]),
                            )),
                          ]
                      )
                  )
              )
            ]
        ),
        body: welcomeText(context),
    );
  }

  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  void dispose() {
    super.dispose();
    controller.dispose();
  }

  Widget welcomeText(context) {
    var assets = DefaultAssetBundle.of(context);
    return FutureBuilder(
      future: assets.loadString("assets/consent-form.md"),
      builder: (context, snapshot) =>
      snapshot.hasData ?
      Align(
          alignment: Alignment.centerLeft,
          child: Markdown(
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(textScaleFactor: textScale),
            data: snapshot.data,
          )
      ):
      Text("loading..."),
    );
  }
}