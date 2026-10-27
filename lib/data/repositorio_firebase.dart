import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/codigo.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
import '../models/salud.dart';
import '../models/usuario.dart';
import 'repositorio.dart';

// Firestore sigue el diagrama ER del equipo (ver docs/superpowers/specs).
class RepositorioFirebase implements RepositorioNana {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _azar = Random.secure();

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _db.collection('usuarios');
  CollectionReference<Map<String, dynamic>> get _adultos =>
      _db.collection('adultos');
  CollectionReference<Map<String, dynamic>> get _codigos =>
      _db.collection('codigos');
  CollectionReference<Map<String, dynamic>> _de(String folio, String sub) =>
      _adultos.doc(folio).collection(sub);

  // Traduce los errores de Firebase a algo que se pueda leer.
  Future<T> _intentar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ErrorNana {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw ErrorNana(switch (e.code) {
        'email-already-in-use' => 'Ese correo ya tiene cuenta. Inicia sesión.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' => 'El correo o la contraseña no coinciden.',
        'weak-password' =>
          'La contraseña necesita al menos 6 letras o números.',
        'network-request-failed' => 'No hay internet. Revisa tu conexión.',
        'too-many-requests' =>
          'Fueron muchos intentos. Espera unos minutos y vuelve a probar.',
        _ => 'No se pudo entrar. Intenta de nuevo.',
      });
    } on FirebaseException catch (e) {
      throw ErrorNana(
        e.code == 'unavailable'
            ? 'No hay internet. Revisa tu conexión.'
            : 'Algo salió mal. Intenta de nuevo.',
      );
    }
  }

  @override
  String? get uid => _auth.currentUser?.uid;

  @override
  Future<Usuario?> usuarioActual() => _intentar(() async {
    final u = uid;
    if (u == null) return null;
    final d = (await _usuarios.doc(u).get()).data();
    if (d == null) return null;
    return Usuario(
      uid: u,
      nombre: d['nombre'] ?? '',
      apellidos: d['apellidos'] ?? '',
      rol: d['rol'] == 'adulto' ? Rol.adulto : Rol.cuidador,
    );
  });

  Future<void> _guardarUsuario(
    String uid, {
    required String nombre,
    required String apellidos,
    required Rol rol,
    String? correo,
    String? telefono,
  }) => _usuarios.doc(uid).set({
    'nombre': nombre,
    'apellidos': apellidos,
    'correo': correo,
    'telefono': telefono,
    'rol': rol.name,
    'estado': 'activo',
    'creado': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> crearCuentaCuidador({
    required String nombre,
    required String apellidos,
    required String telefono,
    required String correo,
    required String contrasena,
  }) => _intentar(() async {
    final c = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
    await _guardarUsuario(
      c.user!.uid,
      nombre: nombre,
      apellidos: apellidos,
      rol: Rol.cuidador,
      correo: correo.trim(),
      telefono: telefono,
    );
  });

  @override
  Future<void> iniciarSesion(String correo, String contrasena) => _intentar(
    () => _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    ),
  );

  @override
  Future<void> restablecerContrasena(String correo) =>
      _intentar(() => _auth.sendPasswordResetEmail(email: correo.trim()));

  @override
  Future<void> registrarAdulto({
    required String nombre,
    required String apellidos,
    required String correo,
    required String contrasena,
  }) => _intentar(() async {
    final c = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
    final u = c.user!.uid;
    await _guardarUsuario(
      u,
      nombre: nombre,
      apellidos: apellidos,
      rol: Rol.adulto,
      correo: correo.trim(),
    );
    await _adultos.add({
      'nombre': nombre,
      'apellidos': apellidos,
      'tieneCelular': true,
      'uidAdulto': u,
      'idsCuidadores': <String>[],
      'creadoPor': u,
      'fechaReg': FieldValue.serverTimestamp(),
    });
  });

  // El celular del adulto entra como usuario anónimo (sin correo ni contraseña)
  // y queda ligado a su folio. Las reglas revisan el código en el mismo batch.
  @override
  Future<Adulto> canjearCodigo(String codigo) => _intentar(() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    final u = uid!;
    final doc = await _codigos.doc(codigo).get();
    final d = doc.data();
    if (d == null ||
        d['usado'] == true ||
        (d['expira'] as Timestamp).toDate().isBefore(DateTime.now())) {
      throw const ErrorNana(errorCodigo);
    }
    final folio = d['folio'] as String;
    final nombre = d['nombreAdulto'] as String? ?? '';
    final apellidos = d['apellidosAdulto'] as String? ?? '';

    final batch = _db.batch()
      ..update(_codigos.doc(codigo), {'usado': true, 'usadoPor': u})
      ..update(_adultos.doc(folio), {
        'uidAdulto': u,
        'tieneCelular': true,
        'codigoCanjeado': codigo,
      })
      ..set(_usuarios.doc(u), {
        'nombre': nombre,
        'apellidos': apellidos,
        'correo': null,
        'telefono': null,
        'rol': Rol.adulto.name,
        'estado': 'activo',
        'creado': FieldValue.serverTimestamp(),
      });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // Si las reglas lo niegan es que alguien lo usó o venció entre medio.
      if (e.code == 'permission-denied') throw const ErrorNana(errorCodigo);
      rethrow;
    }
    return (await adultoPropio())!;
  });

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<String> altaAdulto({
    required String nombre,
    required String apellidos,
    required String parentesco,
    required bool tieneCelular,
    String? telefono,
  }) => _intentar(() async {
    final u = uid!;
    final yo = await usuarioActual();
    final ref = _adultos.doc();
    final batch = _db.batch()
      ..set(ref, {
        'nombre': nombre,
        'apellidos': apellidos,
        'tieneCelular': tieneCelular,
        'telefono': telefono,
        'uidAdulto': null,
        'idsCuidadores': [u],
        'creadoPor': u,
        'fechaReg': FieldValue.serverTimestamp(),
      })
      ..set(ref.collection('cuidadores').doc(u), {
        'nombre': yo?.nombre ?? '',
        'parentesco': parentesco,
        'fechaIni': FieldValue.serverTimestamp(),
        'estado': 'activo',
      });
    await batch.commit();
    return ref.id;
  });

  @override
  Future<CodigoVinculacion> generarCodigo(String folio) => _intentar(() async {
    final adulto = (await _adultos.doc(folio).get()).data() ?? {};
    final expira = DateTime.now().add(vigenciaCodigo);
    // Si el número ya existe, las reglas niegan pisarlo; se prueba con otro.
    for (var intento = 0; intento < 5; intento++) {
      final codigo = codigoAlAzar(_azar);
      try {
        await _codigos.doc(codigo).set({
          'folio': folio,
          'nombreAdulto': adulto['nombre'] ?? '',
          'apellidosAdulto': adulto['apellidos'] ?? '',
          'creadoPor': uid,
          'expira': Timestamp.fromDate(expira),
          'usado': false,
        });
        return CodigoVinculacion(codigo: codigo, folio: folio, expira: expira);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    throw const ErrorNana('No se pudo crear el código. Intenta de nuevo.');
  });

  @override
  Stream<bool> codigoUsado(String codigo) => _codigos
      .doc(codigo)
      .snapshots()
      .map((s) => s.data()?['usado'] == true);

  Adulto _adulto(
    DocumentSnapshot<Map<String, dynamic>> s, {
    String? parentesco,
  }) {
    final d = s.data()!;
    return Adulto(
      folio: s.id,
      nombre: d['nombre'] ?? '',
      apellidos: d['apellidos'] ?? '',
      tieneCelular: d['tieneCelular'] == true,
      uidAdulto: d['uidAdulto'],
      idsCuidadores: List<String>.from(d['idsCuidadores'] ?? const []),
      parentesco: parentesco,
      telefono: d['telefono'],
    );
  }

  @override
  Stream<List<Adulto>> adultosACargo() {
    final u = uid;
    if (u == null) return Stream.value(const []);
    return _adultos
        .where('idsCuidadores', arrayContains: u)
        .snapshots()
        .asyncMap(
          (q) => Future.wait(
            q.docs.map((s) async {
              final c = await s.reference
                  .collection('cuidadores')
                  .doc(u)
                  .get();
              return _adulto(s, parentesco: c.data()?['parentesco']);
            }),
          ),
        );
  }

  @override
  Future<Adulto?> adultoPropio() => _intentar(() async {
    final u = uid;
    if (u == null) return null;
    final q = await _adultos.where('uidAdulto', isEqualTo: u).limit(1).get();
    return q.docs.isEmpty ? null : _adulto(q.docs.first);
  });

  @override
  Future<String> nombreDeCuidador(String folio) => _intentar(() async {
    final q = await _de(folio, 'cuidadores').limit(1).get();
    return q.docs.isEmpty ? '' : q.docs.first.data()['nombre'] ?? '';
  });

  @override
  Stream<List<Medicamento>> medicamentos(String folio) => _de(folio, 'medicamentos')
      .orderBy('hora')
      .snapshots()
      .map(
        (q) => [
          for (final s in q.docs)
            Medicamento(
              id: s.id,
              nombre: s['nombre'],
              dosis: s['dosis'],
              hora: Medicamento.leerHora(s['hora']),
              ventanaMin: s['ventanaMin'],
            ),
        ],
      );

  @override
  Future<void> guardarMedicamento(String folio, Medicamento m) =>
      _intentar(() async {
        final datos = {
          'nombre': m.nombre,
          'dosis': m.dosis,
          'hora': m.horaTexto,
          'ventanaMin': m.ventanaMin,
          'estado': 'activo',
        };
        final col = _de(folio, 'medicamentos');
        // Sin await: con mala señal Firestore lo guarda y lo manda después.
        unawaited(m.id == null ? col.add(datos) : col.doc(m.id).set(datos));
      });

  @override
  Future<void> borrarMedicamento(String folio, String id) async =>
      unawaited(_de(folio, 'medicamentos').doc(id).delete());

  @override
  Stream<List<Registro>> registrosDeHoy(String folio) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    return _de(folio, 'registros')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(hoy))
        .orderBy('fecha')
        .snapshots()
        .map(
          (q) => [
            for (final s in q.docs)
              Registro(
                id: s.id,
                tipo: TipoActividad.values.byName(s['tipo']),
                titulo: s['titulo'],
                idMedicamento: s.data()['idMedicamento'],
                valor: s.data()['valor'],
                fecha: (s['fecha'] as Timestamp).toDate(),
                registradoPor: s['registradoPor'],
              ),
          ],
        );
  }

  @override
  Future<void> registrar(String folio, Registro r) async {
    unawaited(
      _de(folio, 'registros').add({
        'tipo': r.tipo.name,
        'titulo': r.titulo,
        'idMedicamento': r.idMedicamento,
        'valor': r.valor,
        'fecha': Timestamp.fromDate(r.fecha),
        'registradoPor': r.registradoPor,
      }),
    );
    unawaited(
      _adultos.doc(folio).update({
        'ultimaActividad': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Stream<Salud> salud(String folio) => _adultos.doc(folio).snapshots().map((s) {
    final d = s.data()?['salud'] as Map<String, dynamic>?;
    return Salud.deMapa(d).copyWith(
      actualizado: (d?['actualizado'] as Timestamp?)?.toDate(),
    );
  });

  @override
  Future<void> guardarSalud(String folio, Salud s) async => unawaited(
    _adultos.doc(folio).update({
      'salud': {
        ...s.aMapa(),
        'actualizado': FieldValue.serverTimestamp(),
        'actualizadoPor': uid,
      },
    }),
  );

  @override
  Stream<List<Alerta>> alertasSinAtender(String folio) =>
      _de(folio, 'alertas')
          .where('atendida', isEqualTo: false)
          .snapshots()
          .map(
            (q) => [
              for (final s in q.docs)
                Alerta(
                  id: s.id,
                  fecha:
                      (s.data()['fecha'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                ),
            ],
          );

  @override
  Future<bool> pedirAyuda(String folio) async {
    final escrito = _de(folio, 'alertas').add({
      'tipo': 'pide_ayuda',
      'fecha': Timestamp.now(),
      'atendida': false,
      'creadaPor': uid,
    });
    // add() termina cuando el servidor lo confirma. Sin internet se queda en
    // cola y se manda solo después; aquí solo decimos la verdad sobre eso.
    try {
      await escrito.timeout(const Duration(seconds: 8));
      return true;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> atenderAlerta(String folio, String id) async => unawaited(
    _de(folio, 'alertas').doc(id).update({
      'atendida': true,
      'atendidaPor': uid,
    }),
  );
}
