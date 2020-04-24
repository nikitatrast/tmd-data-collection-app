import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../boundaries/preferences_provider.dart' show UidStore;

class RegisterPage extends StatefulWidget {
  final VoidCallback next;
  final UidStore uidStore;

  @override
  _RegisterPageState createState() => _RegisterPageState();

  RegisterPage(this.uidStore, this.next);
}

class _RegisterPageState extends State<RegisterPage> {
  TextEditingController controller;
  double textScale = 1.0;
  double maxScale = 2.0;
  double minScale = 0.9;
  double defaultScale = 1.0;

  @override
  Widget build(BuildContext context) {
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
        body: Scrollbar(
            child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              welcomeText(context),
              Container(
                  padding: EdgeInsets.only(left: 10, right: 10),
                  child: TextField(
                      controller: controller,
                      decoration:
                          InputDecoration(labelText: 'Nom de l\'appareil'))),
              ButtonBar(
                children: [
                  RaisedButton(
                      child: Text("J'accepte"),
                      color: Colors.blue,
                      onPressed: () async {
                        var text = controller.text;
                        widget.uidStore.setLocalUid(text);
                        print('[RegisterPage] Local uid: $text');
                        widget.next();
                      }),
                ])
            ]),
          ),
        )));
  }

  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  void dispose() {
    super.dispose();
    controller.dispose();
  }

  Widget welcomeText(context) =>
      Align(
          alignment: Alignment.centerLeft,
          child: MarkdownBody(
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(textScaleFactor: textScale),
              data: markdownText
          )
      );
}

final ifGpsActivated = "(si vous l'avez activé)";

final markdownText = """
Cette application permet de participer à un projet de recherche en intelligence artificielle en rapport avec la Détection automatique du Mode de Transport (DMT).

Ce projet de recherche est mené par Julien Harbulot en partenariat avec le laboratoire de recherche TRANSP-OR de l'École Polytechnique Fédérale de Lausanne et l'entreprise Elca Informatique SA.

# Contexte

Dans de nombreuses applications, l'expérience utilisateur peut être améliorée en détectant le mode de transport courant, c'est à dire si l'utilisateur est en train de se déplacer à pied, en vélo, en voiture, etc. Par exemple, une application de réalité augmentée (comme Pokemon GO) pourra faire monter le joueur automatiquement dans une voiture ou un vélo si ce mode de transport est détecté. Ou encore, une application de fitness comptera une dépense énergétique plus grande lors d'un trajet à pied que lors d'un trajet en voiture.

Pour détecter automatiquement le mode de transport, une intelligence artificielle (IA) est utilisée pour analyser les données des capteurs du smartphone, comme par exemple celles de l'accéléromètre ou du GPS. Avant de pouvoir analyser de nouvelles données, l'IA doit être entrainée avec des exemples de trajet dont on connait le mode de transport avec précision. 

En utilisant cette application, vous participez à la collecte de tels exemples ; **il est donc très important que vous renseignez le bon mode de transport pour permettre à l'IA d'apprendre correctement**.

# Fonctionnement de l'application

Lors d'un trajet dans lequel n'intervient qu'un seul mode de transport (par exemple, un trajet en voiture), ouvrez l'application et selectionez le mode de transport correspondant. Cela démarrera automatiquement la collecte des données. À la fin de votre de trajet et *avant de changer de mode de transport* (par exemple, avant de sortir de la voiture), enregistrez votre trajet pour terminer la collecte, valider les données et les transmettre au serveur.

Dans la page de gestion des préférences, vous pouvez paramétrer le fonctionnement de l'application. Par exemple, pour préserver votre abonnement réseau, vous pouvez choisir de ne synchroniser les données avec le serveur seulement lorsqu'une connection wifi est disponible.

Lors de la collecte des données, l'application enregistre également votre position GPS $ifGpsActivated. Pour votre confort d'utilisation, vous pouvez définir des *zones privées* à l'intérieur desquelles nous ne publierons pas votre position GPS. Par exemple, vous pouvez utiliser cette fonctionalité pour dissimuler l'addresse de votre domicile ou de votre lieu de travail.


# Données collectées

L'abscence de données publiques de haute qualité est un frein majeur aux recherches sur la détection automatique du mode de transport. Afin de faciliter les recherches dans ce domaine, les données collectées seront publiées sur internet.

Les données sont uniquement collectées lorsque vous choisissez d'enregistrer un nouveau trajet. Dès la fin du trajet, la collecte des données est arrêtée. 

Aucune information personnelle vous concernant n'est collectée. En particulier, votre nom et votre numéro de téléphone ne sont jamais collectés. 

Pour le bon fonctionnement de la synchronisation des données, notre serveur peut avoir accès à certaines information concernant votre appareil, comme l'adresse IP utilisée pour établir la connection ou l'ID de l'application. En aucun cas ces données ne seront publiées.

Uniquement les données suivantes seront publiées sur internet :

- les données des capteurs suivants: 
   - accéléromètre ;
- les données du GPS qui *ne sont pas* à l'intérieur de vos zones privées.

# Consentement

En utilisant cette application, vous acceptez :

- de renseigner correctement le mode de transport utilisé lors de la collecte des données ;
- que les données des capteurs mentionés plus haut seront publiées sur internet pour faciliter les traveaux de recherches en DMT ;
- qu'aucune information personnelle vous concernant ne sera publiée.

Pour donner votre consentement, entrez un identifiant pour pouvoir enregistrer votre appareil auprès du serveur de données.
""";