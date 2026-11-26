import '../models/medicina_leida.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'agente.dart';
import 'ajustes.dart';

Agente crearAgente() => AgenteEnRed();

/// Habla con `agente/servidor_local.py` por la red (Wi-Fi o hotspot). Usa
/// `HttpClient` de Dart para no sumar paquetes. Cualquier falla regresa null
/// y la plática sigue con sus respuestas de siempre.
class AgenteEnRed implements Agente {
  final Duration limite;
  final String Function() _servidor;
  final String Function() _clave;

  AgenteEnRed({
    this.limite = const Duration(seconds: 6),
    String Function()? servidor,
    String Function()? clave,
  }) : _servidor = servidor ?? (() => Ajustes.servidorAgente.value),
       _clave = clave ?? (() => Ajustes.claveAgente.value);

  @override
  bool get disponible => urlDelServidor(_servidor()) != null;

  @override
  Future<RespuestaAgente?> preguntar({
    required String texto,
    required String nombre,
    required List<Map<String, Object?>> dia,
    required List<Map<String, String>> historial,
  }) async => RespuestaAgente.deJson(
    await _pedir('POST', '/agente', {
      'texto': texto,
      'nombre': nombre,
      'dia': dia,
      'historial': historial,
    }),
  );

  @override
  Future<RespuestaAgente?> preguntarEncargado({
    required String pregunta,
    required String nombre,
    required Map<String, Object?> datos,
    required List<Map<String, String>> historial,
  }) async => RespuestaAgente.deJson(
    await _pedir('POST', '/encargado', {
      'pregunta': pregunta,
      'nombre': nombre,
      'datos': datos,
      'historial': historial,
    }),
  );

  @override
  Future<SaludAgente?> salud() async {
    final j = await _pedir('GET', '/salud');
    if (j == null || j['ok'] != true) return null;
    return SaludAgente(
      modelo: '${j['ollama'] ?? j['proveedores'] ?? 'agente'}',
      claveOk: j['clave_ok'] != false,
    );
  }

  @override
  Future<List<MedicinaLeida>?> leerReceta(String texto) async =>
      medicinasDeJson(
        // Leer una receta toma más que una frase: hasta 20 s.
        await _pedir('POST', '/receta', {
          'texto': texto,
        }, const Duration(seconds: 20)),
      );

  Future<Map<String, dynamic>?> _pedir(
    String metodo,
    String ruta, [
    Map<String, Object?>? cuerpo,
    Duration? tiempo,
  ]) async {
    final base = urlDelServidor(_servidor());
    if (base == null) return null;
    final espera = tiempo ?? limite;
    final cliente = HttpClient()..connectionTimeout = limite;
    try {
      return await _hacer(
        cliente,
        metodo,
        '$base$ruta',
        cuerpo,
      ).timeout(espera, onTimeout: () => null);
    } catch (e) {
      debugPrint('NANA agente: $metodo $ruta falló: $e');
      return null;
    } finally {
      cliente.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _hacer(
    HttpClient cliente,
    String metodo,
    String url,
    Map<String, Object?>? cuerpo,
  ) async {
    final pedido = await cliente.openUrl(metodo, Uri.parse(url));
    // La clave de la demo (NANA_CLAVE_DEMO en la laptop), si se puso.
    final clave = _clave().trim();
    if (clave.isNotEmpty) pedido.headers.set('X-Nana-Demo', clave);
    if (cuerpo != null) {
      final bytes = utf8.encode(jsonEncode(cuerpo));
      pedido.headers.contentType = ContentType.json;
      // Sin el tamaño, Dart lo manda "en pedazos" (chunked) y el servidor de
      // Python lee Content-Length = 0: lo toma como petición vacía (400).
      pedido.contentLength = bytes.length;
      pedido.add(bytes);
    }
    final respuesta = await pedido.close();
    final texto = await respuesta.transform(utf8.decoder).join();
    if (respuesta.statusCode != 200) {
      // Se ve en la terminal de `flutter run`; NANA sigue con su respaldo.
      debugPrint('NANA agente: $metodo $url -> ${respuesta.statusCode} $texto');
      return null;
    }
    final j = jsonDecode(texto);
    return j is Map<String, dynamic> ? j : null;
  }
}
