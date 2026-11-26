import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/servicios.dart';
import '../core/codigo.dart';
import '../core/medicion.dart';
import '../models/actividad.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/apariencia.dart';
import '../models/medicamento.dart';
import '../models/receta.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
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
        'email-already-in-use' || 'credential-already-in-use' =>
          'Ese correo ya tiene cuenta. Inicia sesión.',
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
    // Quien revisó una invitación ya tiene una sesión anónima: esa misma se
    // convierte en su cuenta, en vez de dejar una sesión huérfana.
    final actual = _auth.currentUser;
    final c = actual != null && actual.isAnonymous
        ? await actual.linkWithCredential(
            EmailAuthProvider.credential(
              email: correo.trim(),
              password: contrasena,
            ),
          )
        : await _auth.createUserWithEmailAndPassword(
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
    if (d['tipo'] == 'familiar') throw const ErrorNana(errorCodigoFamiliar);
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

  // Las reglas piden sesión para leer un código, así que quien todavía no
  // tiene cuenta entra como anónimo (igual que el celular del adulto).
  @override
  Future<Invitacion> revisarInvitacion(String codigo) => _intentar(() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
    final d = (await _codigos.doc(codigo).get()).data();
    if (d == null ||
        d['usado'] == true ||
        (d['expira'] as Timestamp).toDate().isBefore(DateTime.now())) {
      throw const ErrorNana(errorCodigo);
    }
    if (d['tipo'] != 'familiar') throw const ErrorNana(errorCodigoDelAdulto);
    return Invitacion(
      codigo: codigo,
      nombreAdulto: d['nombreAdulto'] as String? ?? '',
      nombreInvita: d['nombreInvita'] as String? ?? '',
    );
  });

  // Un familiar con cuenta de cuidador canjea su invitación. Todavía no puede
  // leer al adulto (no es de la familia), así que todo va en un batch y las
  // reglas revisan el código ahí mismo.
  @override
  Future<Adulto> unirmeComoFamiliar(String codigo, String parentesco) =>
      _intentar(() async {
        final u = uid;
        if (u == null) throw const ErrorNana(errorCodigo);
        final d = (await _codigos.doc(codigo).get()).data();
        if (d == null ||
            d['usado'] == true ||
            (d['expira'] as Timestamp).toDate().isBefore(DateTime.now())) {
          throw const ErrorNana(errorCodigo);
        }
        if (d['tipo'] != 'familiar') {
          throw const ErrorNana(errorCodigoDelAdulto);
        }
        final folio = d['folio'] as String;
        final mios = await _adultos
            .where('idsCuidadores', arrayContains: u)
            .get();
        if (mios.docs.any((a) => a.id == folio)) {
          throw const ErrorNana(errorYaLaCuidas);
        }
        final yo = (await _usuarios.doc(u).get()).data() ?? {};

        final batch = _db.batch()
          ..update(_codigos.doc(codigo), {'usado': true, 'usadoPor': u})
          ..update(_adultos.doc(folio), {
            'idsCuidadores': FieldValue.arrayUnion([u]),
            'codigoFamiliar': codigo,
          })
          ..set(_de(folio, 'cuidadores').doc(u), {
            'nombre': yo['nombre'] ?? '',
            'telefono': yo['telefono'],
            'parentesco': parentesco,
            'fechaIni': FieldValue.serverTimestamp(),
            'estado': 'activo',
          });
        try {
          await batch.commit();
        } on FirebaseException catch (e) {
          // Si las reglas lo niegan es que alguien lo usó o venció entre medio.
          if (e.code == 'permission-denied') throw const ErrorNana(errorCodigo);
          rethrow;
        }
        return _adulto(await _adultos.doc(folio).get(), parentesco: parentesco);
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
    final miTelefono = (await _usuarios.doc(u).get()).data()?['telefono'];
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
        // Solo se llega aquí después de aceptar la pantalla de permiso.
        'consentimiento': {
          'por': u,
          'fecha': FieldValue.serverTimestamp(),
          'version': 1,
        },
      })
      ..set(ref.collection('cuidadores').doc(u), {
        'nombre': yo?.nombre ?? '',
        'telefono': miTelefono,
        'parentesco': parentesco,
        'fechaIni': FieldValue.serverTimestamp(),
        'estado': 'activo',
      });
    await batch.commit();
    return ref.id;
  });

  // Las reglas son las que mandan: si no es el principal, Firestore lo niega.
  Future<void> _comoPrincipal(Future<void> Function() accion) async {
    try {
      await accion();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const ErrorNana(errorSinPermiso);
      }
      rethrow;
    }
  }

  @override
  Future<void> nombrarSuplente(String folio, String uid, {DateTime? hasta}) =>
      _intentar(
        () => _comoPrincipal(
          () => _adultos.doc(folio).update({
            'suplente': {
              'uid': uid,
              'hasta': hasta == null ? null : Timestamp.fromDate(hasta),
              'desde': FieldValue.serverTimestamp(),
            },
          }),
        ),
      );

  @override
  Future<void> quitarSuplente(String folio) => _intentar(
    () => _comoPrincipal(
      () => _adultos.doc(folio).update({'suplente': FieldValue.delete()}),
    ),
  );

  @override
  Future<void> quitarFamiliar(String folio, String uid) => _intentar(
    () => _comoPrincipal(() async {
      final d = (await _adultos.doc(folio).get()).data() ?? {};
      final eraSuplente = _suplente(d['suplente'])?.uid == uid;
      final batch = _db.batch()
        ..update(_adultos.doc(folio), {
          'idsCuidadores': FieldValue.arrayRemove([uid]),
          if (eraSuplente) 'suplente': FieldValue.delete(),
        })
        ..delete(_de(folio, 'cuidadores').doc(uid));
      await batch.commit();
    }),
  );

  @override
  Future<void> dejarDeAcompanar(String folio) => _intentar(() async {
    final u = uid;
    if (u == null) return;
    final d = (await _adultos.doc(folio).get()).data() ?? {};
    if (d['creadoPor'] == u) throw const ErrorNana(errorPrincipalNoSale);
    final eraSuplente = _suplente(d['suplente'])?.uid == u;
    // Primero la fila (la regla de borrar revisa que todavía sea de la
    // familia), luego se quita de idsCuidadores.
    final batch = _db.batch()
      ..delete(_de(folio, 'cuidadores').doc(u))
      ..update(_adultos.doc(folio), {
        'idsCuidadores': FieldValue.arrayRemove([u]),
        if (eraSuplente) 'suplente': FieldValue.delete(),
      });
    await batch.commit();
  });

  @override
  Stream<Apariencia?> apariencia(String folio) => _adultos
      .doc(folio)
      .snapshots()
      .map(
        (s) =>
            Apariencia.deMapa(s.data()?['apariencia'] as Map<String, dynamic>?),
      );

  @override
  Future<void> guardarApariencia(String folio, Apariencia a) => _intentar(
    () => _comoPrincipal(
      () => _adultos.doc(folio).update({
        'apariencia': a.copyWith(actualizado: DateTime.now()).aMapa(),
      }),
    ),
  );

  @override
  Future<void> guardarEstudio(String folio, bool activo) => _intentar(
    () => _comoPrincipal(() => _adultos.doc(folio).update({'estudio': activo})),
  );

  // Un número al azar por cada vez que se abre la app: junta los eventos de
  // una misma sesión sin decir de quién son. No se guarda el uid.
  late final _sesionUso = List.generate(
    12,
    (_) => _azar.nextInt(36).toRadixString(36),
  ).join();

  @override
  Future<void> guardarUso(List<EventoUso> lote, {required String rol}) =>
      _db.collection('uso').add({
        'sesion': _sesionUso,
        'rol': rol,
        'creado': FieldValue.serverTimestamp(),
        'eventos': [for (final e in lote) e.aMapa()],
      });

  @override
  Future<bool> puedeVerEstudio() async {
    final u = uid;
    if (u == null) return false;
    try {
      return (await _db.collection('estudio_admins').doc(u).get()).exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<List<EventoUso>> usoReciente() => _intentar(() async {
    try {
      final q = await _db
          .collection('uso')
          .orderBy('creado', descending: true)
          .limit(300)
          .get();
      return [
        for (final d in q.docs)
          for (final e in (d.data()['eventos'] as List? ?? const []))
            if (e is Map) ?EventoUso.deMapa(Map<String, dynamic>.from(e)),
      ];
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const ErrorNana(errorSinPermiso);
      }
      rethrow;
    }
  });

  // Primero lo de adentro (las reglas todavía necesitan leer al adulto) y al
  // final el adulto. Los códigos viejos no se pueden listar: vencen solos.
  @override
  Future<void> borrarAdulto(String folio) => _intentar(() async {
    final doc = await _adultos.doc(folio).get();
    if (!doc.exists) return;
    if (doc.data()?['creadoPor'] != uid) {
      throw const ErrorNana(errorSoloEncargado);
    }
    for (final sub in const [
      'medicamentos',
      'registros',
      'alertas',
      'rutinas',
      'recetas',
      'citas',
      'cuidadores',
    ]) {
      final docs = (await _de(folio, sub).get()).docs;
      for (var i = 0; i < docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _adultos.doc(folio).delete();
  });

  @override
  Future<CodigoVinculacion> generarCodigo(
    String folio, {
    bool familiar = false,
  }) => _intentar(() async {
    final adulto = (await _adultos.doc(folio).get()).data() ?? {};
    // Invitar es del principal; el código del adulto también lo saca el suplente.
    final suplente = _suplente(adulto['suplente']);
    final esSuplente =
        suplente?.uid == uid && (suplente?.vigente(DateTime.now()) ?? false);
    if (adulto['creadoPor'] != uid && (familiar || !esSuplente)) {
      throw const ErrorNana(errorSinPermiso);
    }
    final expira = DateTime.now().add(vigenciaCodigo);
    final invita = familiar ? (await usuarioActual())?.nombre ?? '' : '';
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
          if (familiar) 'tipo': 'familiar',
          if (familiar) 'nombreInvita': invita,
        });
        return CodigoVinculacion(
          codigo: codigo,
          folio: folio,
          expira: expira,
          familiar: familiar,
        );
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    throw const ErrorNana('No se pudo crear el código. Intenta de nuevo.');
  });

  @override
  Stream<bool> codigoUsado(String codigo) =>
      _codigos.doc(codigo).snapshots().map((s) => s.data()?['usado'] == true);

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
      creadoPor: d['creadoPor'],
      consentimiento:
          ((d['consentimiento'] as Map<String, dynamic>?)?['fecha']
                  as Timestamp?)
              ?.toDate(),
      suplente: _suplente(d['suplente']),
      estudio: d['estudio'] == true,
    );
  }

  Suplente? _suplente(Object? m) {
    if (m is! Map || m['uid'] is! String) return null;
    return Suplente(
      uid: m['uid'] as String,
      hasta: (m['hasta'] as Timestamp?)?.toDate(),
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
              final c = await s.reference.collection('cuidadores').doc(u).get();
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
  Stream<List<Familiar>> familiaDe(String folio) =>
      _de(folio, 'cuidadores').snapshots().map(
        (q) => [
          for (final d in q.docs)
            Familiar(
              uid: d.id,
              nombre: d.data()['nombre'] ?? '',
              telefono: d.data()['telefono'],
            ),
        ],
      );

  @override
  Future<void> compartirMiTelefono(String folio) => _intentar(() async {
    final u = uid;
    if (u == null) return;
    final telefono = (await _usuarios.doc(u).get()).data()?['telefono'];
    if (telefono == null || telefono == '') return;
    final fila = _de(folio, 'cuidadores').doc(u);
    if ((await fila.get()).data()?['telefono'] == telefono) return;
    await fila.update({'telefono': telefono});
  });

  @override
  Stream<List<Medicamento>> medicamentos(String folio) =>
      _de(folio, 'medicamentos')
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
        .map((q) => [for (final s in q.docs) _registro(s)]);
  }

  Registro _registro(QueryDocumentSnapshot<Map<String, dynamic>> s) => Registro(
    id: s.id,
    tipo: TipoActividad.values.byName(s['tipo']),
    titulo: s['titulo'],
    idMedicamento: s.data()['idMedicamento'],
    valor: s.data()['valor'],
    fecha: (s['fecha'] as Timestamp).toDate(),
    registradoPor: s['registradoPor'],
  );

  @override
  Future<String> registrar(String folio, Registro r) async {
    // El id se conoce antes de mandar, así funciona aun sin señal.
    final ref = _de(folio, 'registros').doc();
    unawaited(
      ref.set({
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
    return ref.id;
  }

  @override
  Future<void> borrarRegistro(String folio, String id) async =>
      unawaited(_de(folio, 'registros').doc(id).delete());

  @override
  Stream<Salud> salud(String folio) => _adultos.doc(folio).snapshots().map((s) {
    final d = s.data()?['salud'] as Map<String, dynamic>?;
    return Salud.deMapa(d)
        .copyWith(actualizado: (d?['actualizado'] as Timestamp?)?.toDate());
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
  Stream<List<Alerta>> alertasSinAtender(String folio) => _de(folio, 'alertas')
      .where('atendida', isEqualTo: false)
      .snapshots()
      .map(
        (q) => [
          for (final s in q.docs)
            Alerta(
              id: s.id,
              fecha:
                  (s.data()['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
              tipo: s.data()['tipo'] as String? ?? 'pide_ayuda',
              texto: s.data()['texto'] as String?,
              respuestas: RespuestaAlerta.deMapa(s.data()['respuestas']),
              como: s.data()['como'] as String? ?? 'boton',
            ),
        ],
      );

  @override
  Future<bool> pedirAyuda(String folio, {String como = 'boton'}) async {
    final escrito = _de(folio, 'alertas').add({
      'tipo': 'pide_ayuda',
      'como': como,
      'fecha': Timestamp.now(),
      'atendida': false,
      'creadaPor': uid,
    });
    // add() termina cuando el servidor lo confirma. Sin internet se queda en
    // cola y se manda solo después; aquí solo decimos la verdad sobre eso.
    try {
      await escrito.timeout(const Duration(seconds: 8));
      // Que el Worker mande el push ya, sin esperar a su revisión del minuto.
      Servicios.push.avisarAhora(folio).ignore();
      return true;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> avisarFrase(String folio, String frase) async => unawaited(
    _de(folio, 'alertas')
        .add({
          'tipo': 'frase',
          'texto': frase,
          'fecha': Timestamp.now(),
          'atendida': false,
          'creadaPor': uid,
        })
        .then((_) => Servicios.push.avisarAhora(folio)),
  );

  @override
  Future<void> guardarTokenPush(String token) async {
    final u = uid;
    if (u == null) return;
    await _usuarios.doc(u).set({
      'tokensPush': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> atenderAlerta(String folio, String id) async => unawaited(
    _de(
      folio,
      'alertas',
    ).doc(id).update({'atendida': true, 'atendidaPor': uid}),
  );

  @override
  Future<void> responderAlerta(String folio, String id, String estado) =>
      _intentar(() async {
        final u = uid;
        if (u == null) return;
        final yo = (await _usuarios.doc(u).get()).data() ?? {};
        final nombre = '${yo['nombre'] ?? ''}'.trim();
        await _de(folio, 'alertas').doc(id).update({
          'respuestas.$u': RespuestaAlerta(
            nombre: nombre,
            estado: estado,
          ).aMapa(),
          if (estado == 'atendi') ...{'atendida': true, 'atendidaPor': u},
        });
      });

  @override
  Stream<ReglasAlerta> reglasAlerta(String folio) => _adultos
      .doc(folio)
      .snapshots()
      .map(
        (s) => ReglasAlerta.deMapa(
          s.data()?['reglasAlerta'] as Map<String, dynamic>?,
        ),
      );

  @override
  Future<void> guardarReglasAlerta(String folio, ReglasAlerta r) async =>
      unawaited(_adultos.doc(folio).update({'reglasAlerta': r.aMapa()}));

  // Guarda sin esperar al servidor: con mala señal Firestore lo manda después.
  Future<void> _guardarEn(
    String folio,
    String sub,
    String? id,
    Map<String, dynamic> datos,
  ) async {
    final col = _de(folio, sub);
    unawaited(id == null ? col.add(datos) : col.doc(id).set(datos));
  }

  Future<void> _borrarDe(String folio, String sub, String id) async =>
      unawaited(_de(folio, sub).doc(id).delete());

  @override
  Stream<List<Rutina>> rutinas(String folio) => _de(folio, 'rutinas')
      .orderBy('hora')
      .snapshots()
      .map((q) => [for (final s in q.docs) Rutina.deMapa(s.id, s.data())]);

  @override
  Future<void> guardarRutina(String folio, Rutina r) =>
      _guardarEn(folio, 'rutinas', r.id, r.aMapa());

  @override
  Future<void> borrarRutina(String folio, String id) =>
      _borrarDe(folio, 'rutinas', id);

  @override
  Stream<List<Receta>> recetas(String folio) => _de(folio, 'recetas')
      .orderBy('fecha', descending: true)
      .snapshots()
      .map(
        (q) => [
          for (final s in q.docs)
            Receta(
              id: s.id,
              medico: s.data()['medico'] ?? '',
              fecha: (s.data()['fecha'] as Timestamp).toDate(),
              indicacion: s.data()['indicacion'] ?? '',
            ),
        ],
      );

  @override
  Future<void> guardarReceta(String folio, Receta r) =>
      _guardarEn(folio, 'recetas', r.id, {
        'medico': r.medico,
        'fecha': Timestamp.fromDate(r.fecha),
        'indicacion': r.indicacion,
      });

  @override
  Future<void> borrarReceta(String folio, String id) =>
      _borrarDe(folio, 'recetas', id);

  @override
  Stream<List<Cita>> citas(String folio) => _de(folio, 'citas')
      .orderBy('fecha')
      .snapshots()
      .map(
        (q) => [
          for (final s in q.docs)
            Cita(
              id: s.id,
              especialidad: s.data()['especialidad'] ?? '',
              fecha: (s.data()['fecha'] as Timestamp).toDate(),
              lugar: s.data()['lugar'] ?? '',
            ),
        ],
      );

  @override
  Future<void> guardarCita(String folio, Cita c) =>
      _guardarEn(folio, 'citas', c.id, {
        'especialidad': c.especialidad,
        'fecha': Timestamp.fromDate(c.fecha),
        'lugar': c.lugar,
      });

  @override
  Future<void> borrarCita(String folio, String id) =>
      _borrarDe(folio, 'citas', id);

  @override
  Stream<List<Registro>> registrosDesde(String folio, DateTime desde) =>
      _de(folio, 'registros')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
          .orderBy('fecha')
          .snapshots()
          .map((q) => [for (final s in q.docs) _registro(s)]);

  @override
  Stream<DateTime?> ultimaActividad(String folio) => _adultos
      .doc(folio)
      .snapshots()
      .map((s) => (s.data()?['ultimaActividad'] as Timestamp?)?.toDate());
}
