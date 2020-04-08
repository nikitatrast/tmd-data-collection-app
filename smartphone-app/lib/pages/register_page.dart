import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  bool showRegister = false;

  @override
  Widget build(BuildContext context) {
    return (!showRegister)
        ? Scaffold(
            appBar: AppBar(title: Text('')),
            body: Center(
                child: Container(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator())))
        : Scaffold(
            appBar: AppBar(
              title: Text('Bienvenue'),
            ),
            body: Scrollbar(
                child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  Text(WELCOME_TEXT),
                  Container(
                      padding: EdgeInsets.only(left: 10, right: 10),
                      child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                              labelText: 'Nom de l\'appareil'))),
                  ButtonBar(children: [
                    RaisedButton(
                        child: Text('Continuer'),
                        onPressed: () async {
                          var text = controller.text;
                          widget.uidStore.setLocalUid(text);
                          print('[RegisterPage] Local uid: $text');
                          widget.next();
                        })
                  ])
                ]),
              ),
            )));
  }

  Future<void> chooseRoute() async {
    var localUid = await widget.uidStore.getLocalUid();
    print('[RegisterPage] localUid: $localUid');
    if (localUid == null) {
      showRegister = true;
    } else {
      widget.next();
    }
  }

  void initState() {
    super.initState();
    controller = TextEditingController();
    // https://stackoverflow.com/questions/49457717/flutter-get-context-in-initstate-method
    // https://stackoverflow.com/questions/44269909/flutter-redirect-to-a-page-on-initstate
    Future.delayed(Duration.zero, chooseRoute);
  }

  void dispose() {
    super.dispose();
    controller.dispose();
  }
}

const WELCOME_TEXT = """
Cette application permet de participer à une collecte de données en rapport avec la détection automatique du mode de transport.
Les données seront utilisées pour entrainer une intelligence artificielle capable d'identifier si l'utilisateur d'un smartphone est en train de se déplacer à pied, en vélo, en voiture, en bus, en train ou en métro.

La réussite du projet dépend avant tout de la qualité des données collectées, aussi veuillez faire extremement attention à choisir le bon mode de transport (marche, vélo, etc) avant de commencer l'enregistrement des données, et d'arrêter l'enregistrement avant de changer de mode de transport.

Par exemple, si vous prévoyez de voyager en voiture, attendez d'avoir démarré le moteur pour commencer la collecte de données et enregistrez les données avant de sortir de votre voiture.

Si vous oubliez d'enregistrer les données avant de changer de mode de transport, ou en cas de toute, préférez annuler l'enregistrement.

Pour commencer, veuillez saisir un identifiant unique pour pouvoir enregistrer votre application auprès du serveur. Cet identifiant restera confidentiel.

Pour rappel, aucune information personnelle ne sera rendue public. 
""";
