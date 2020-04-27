# Data collection app

This repository was created as part of a research project on transportation mode detection using smartphone's sensor data.

Participants can use the smartphone application to record sensor data while traveling. Data is then uploaded to the data-collection server over an HTTPS connection.

This repository contains code for both the smartphone application and the data-collection server. 



## Files organization

```
.
├─ scripts: initialization scripts
├─ certificates: SSL certificates used between the app and the server
├─ docs: documentation and screenshots for this project
├─ smartphone-app: smartphone application implementation
└─ server: data-collection server implementation
```



## How to use

Create SSL certificates. This will also deploy the certificates to the app and the server.

```
./scripts/init.sh
```

Build flutter application.

```
cd smartphone-app
flutter run
```

Run server.

```
cd server
docker-compose up
```



## Smartphone application

The application was coded using the [flutter framework](https://flutter.dev/) for both Android and iOS. See the `./smartphone-app` directory for more information.

<img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/00-consent.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/01-mode.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/02-trip.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/03-confirmation.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/04-settings.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/05-explorer.png" width=200>



## Data collection server

The server is coded in python 3 using [FastAPI](https://fastapi.tiangolo.com/). SSL encryption is handled by [traefik](https://containo.us/traefik/). Orchestration is done with [docker compose](https://docs.docker.com/compose/). See the `./server` directory for more information.



## Authors

This application was developed by Julien Harbulot as part of a joint research project between:

- [EPFL's TRANSP-OR lab](https://www.epfl.ch/labs/transp-or/)
- [Elca informatique SA](https://www.elca.ch/en)



## License

MIT X11 License.

Copyright © 2020, Julien Harbulot

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

The Software is provided “as is”, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders X be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the Software.

Except as contained in this notice, the name of the copyright holders shall not be used in advertising or otherwise to promote the sale, use or other dealings in this Software without prior written authorization from the copyright holders.

