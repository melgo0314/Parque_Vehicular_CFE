import 'package:flutter/widgets.dart';

import 'expediente_web_viewer_stub.dart'
    if (dart.library.html) 'expediente_web_viewer_web.dart'
    as visor;

Widget crearExpedienteWebViewer(String url, {required bool esImagen}) =>
    visor.crearVisor(url, esImagen: esImagen);
