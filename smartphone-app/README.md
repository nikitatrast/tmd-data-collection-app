# Data collection app

This smartphone application was created as part of a research project on transportation mode detection using smartphone's sensor data.

Participants can use this application to record sensor data while traveling. Data is then uploaded to a data-collection server over an HTTPS connection.

Recorded sensors are:

1. GPS (when enabled by the user) ;
2. Accelerometer ;
3. Gyroscope.

To avoid any privacy concern, data is only recorded when the user manually starts a new trip. Data collections stops as soon as the user closes the trip.

Also, the _private geofences_ feature enable user to indicate that a set of GPS coordinates should be kept private.

The application was coded using the [flutter framework](https://flutter.dev/) for both Android and iOS.

To ensure proper data collection even when the screen goes black, data-collection is done through a foreground service on android and the app registers as a gps-based application on iOS. For this reason, GPS can be disable on the Android version but is mandatory on the iOS version.

## Screenshots

<img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/00-consent.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/01-mode.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/02-trip.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/03-confirmation.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/04-settings.png" width=200> <img src="https://raw.githubusercontent.com/julien-h/tmd-data-collection-app/master/docs/images/05-explorer.png" width=200>



### Authors

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

