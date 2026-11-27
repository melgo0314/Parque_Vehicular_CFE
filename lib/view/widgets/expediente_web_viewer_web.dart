// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/widgets.dart';

Widget crearVisor(String url, {required bool esImagen}) {
  if (!esImagen) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final visor = element as html.IFrameElement
          ..src = url
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
        visor.setAttribute('title', 'Documento PDF');
      },
    );
  }

  return HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (Object element) {
      final contenedor = element as html.DivElement
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative'
        ..style.overflow = 'hidden'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.backgroundColor = '#f4f6f4';

      final imagen = html.ImageElement()
        ..src = url
        ..alt = 'Documento del expediente'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.transformOrigin = 'center center'
        ..style.userSelect = 'none'
        ..draggable = false;

      var escala = 1.0;
      var movX = 0.0;
      var movY = 0.0;
      final porcentaje = html.SpanElement()
        ..text = '100%'
        ..style.minWidth = '42px'
        ..style.textAlign = 'center'
        ..style.fontSize = '13px'
        ..style.color = '#26332b';

      void aplicarZoom() {
        imagen.style.transform =
            'translate(${movX}px, ${movY}px) scale($escala)';
        porcentaje.text = '${(escala * 100).round()}%';
        contenedor.style.cursor = escala > 1 ? 'grab' : 'default';
      }

      void cambiarZoom(double cambio) {
        escala = (escala + cambio).clamp(0.5, 4.0).toDouble();
        if (escala <= 1) {
          movX = 0;
          movY = 0;
        }
        aplicarZoom();
      }

      html.ButtonElement boton(String texto, String titulo, double cambio) =>
          html.ButtonElement()
            ..text = texto
            ..title = titulo
            ..style.width = '34px'
            ..style.height = '34px'
            ..style.border = '0'
            ..style.borderRadius = '7px'
            ..style.backgroundColor = '#ffffff'
            ..style.color = '#087f43'
            ..style.fontSize = '21px'
            ..style.cursor = 'pointer'
            ..onClick.listen((_) => cambiarZoom(cambio));

      final controles = html.DivElement()
        ..style.position = 'absolute'
        ..style.top = '12px'
        ..style.right = '12px'
        ..style.zIndex = '2'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.gap = '5px'
        ..style.padding = '5px'
        ..style.borderRadius = '9px'
        ..style.backgroundColor = 'rgba(255,255,255,0.95)'
        ..style.boxShadow = '0 2px 8px rgba(0,0,0,0.2)'
        ..children.addAll([
          boton('−', 'Alejar', -0.25),
          porcentaje,
          boton('+', 'Acercar', 0.25),
        ]);

      imagen.onError.listen((_) {
        contenedor.children
          ..clear()
          ..add(
            html.DivElement()
              ..text =
                  'No se pudo cargar la imagen. Revisa el enlace de Storage.',
          );
      });

      contenedor
        ..append(imagen)
        ..append(controles);
    },
  );
}
