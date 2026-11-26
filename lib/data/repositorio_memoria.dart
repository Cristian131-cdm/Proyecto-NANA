import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/codigo.dart';
import '../core/medicion.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/apariencia.dart';
import '../models/actividad.dart';
import '../models/medicamento.dart';
import '../models/receta.dart';
import '../models/registro.dart';
import '../models/rutina.dart';
import '../models/salud.dart';
import '../models/usuario.dart';
import 'repositorio.dart';

// Versión sin internet para las pruebas. Arranca con Ana (cuidadora, con sesión)
// y Rosa (su mamá, con celular vinculado) como en DatosEjemplo.
class RepositorioMemoria implements RepositorioNana {
  final DateTime Function() reloj;

  // Simula que no hay internet al pedir ayuda.
  bool sinInternet = false;

  RepositorioMemoria({
    DateTime Function()? reloj,
    String? sesion = 'ana',
    bool vacio = false,
  }) : reloj = reloj ?? DateTime.now,
       _uid = sesion {
    if (vacio) return;
    _usuarios['ana'] = const Usuario(
      uid: 'ana',
      nombre: 'Ana',
      apellidos: 'López',
      rol: Rol.cuidador,
    );
    _contrasenas['ana@nana.mx'] = ('ana', 'secreto1');
    _telefonos['ana'] = '5500000002';
    _usuarios['rosa-cel'] = const Usuario(
      uid: 'rosa-cel',
      nombre: 'Rosa',
      apellidos: 'Martínez',
      rol: Rol.adulto,
    );
    _adultos['rosa'] = const Adulto(
      folio: 'rosa',
      nombre: 'Rosa',
      apellidos: 'Martínez',
      tieneCelular: true,
      uidAdulto: 'rosa-cel',
      idsCuidadores: ['ana'],
      telefono: '5500000001',
      creadoPor: 'ana',
    );
    _parentescos[('rosa', 'ana')] = 'mamá';
    _medicamentos['rosa'] = [
      const Medicamento(
        id: 'losartan',
        nombre: 'Losartán',
        dosis: '50 mg',
        hora: TimeOfDay(hour: 8, minute: 0),
        ventanaMin: 30,
      ),
    ];
    const diario = {0, 1, 2, 3, 4, 5, 6};
    _rutinas['rosa'] = [
      const Rutina(
        id: 'desayuno',
        titulo: 'Desayuno',
        tipo: TipoActividad.comida,
        hora: TimeOfDay(hour: 7, minute: 30),
        dias: diario,
      ),
      const Rutina(
        id: 'comida',
        titulo: 'Comida',
        tipo: TipoActividad.comida,
        hora: TimeOfDay(hour: 14, minute: 0),
        dias: diario,
      ),
      const Rutina(
        id: 'caminar',
        titulo: 'Caminar 15 min',
        tipo: TipoActividad.ejercicio,
        hora: TimeOfDay(hour: 18, minute: 0),
        dias: diario,
      ),
    ];
    _recetas['rosa'] = [
      Receta(
        id: 'receta1',
        medico: 'Dr. Pérez',
        fecha: DateTime(2026, 10, 2),
        indicacion: 'Losartán 50 mg · 1 al día',
      ),
    ];
  }

  String? _uid;
  var _siguienteId = 0;
  final _azar = Random(7);
  final _cambios = StreamController<void>.broadcast();

  final _usuarios = <String, Usuario>{};
  final _contrasenas =
      <String, (String, String)>{}; // correo → (uid, contraseña)
  final _telefonos = <String, String>{}; // uid del cuidador → teléfono
  final _adultos = <String, Adulto>{};
  final _parentescos =
      <(String, String), String>{}; // (folio, uid) → parentesco
  final _codigos =
      <String, (CodigoVinculacion, bool)>{}; // código → (datos, usado)
  final _apariencias = <String, Apariencia>{};
  final _invita = <String, String>{}; // código → nombre de quien invitó
  final _medicamentos = <String, List<Medicamento>>{};
  final _registros = <String, List<Registro>>{};
  final _alertas = <String, List<Alerta>>{};
  final _salud = <String, Salud>{};
  final _reglas = <String, ReglasAlerta>{};
  final _rutinas = <String, List<Rutina>>{};
  final _recetas = <String, List<Receta>>{};
  final _citas = <String, List<Cita>>{};
  final _ultima = <String, DateTime>{};

  String _nuevoId() => 'id${_siguienteId++}';
  void _avisar() => _cambios.add(null);

  // Cada quien que escucha recibe el valor actual y luego cada cambio.
  Stream<T> _vigilar<T>(T Function() leer) async* {
    yield leer();
    await for (final _ in _cambios.stream) {
      yield leer();
    }
  }

  @override
  String? get uid => _uid;

  @override
  Future<Usuario?> usuarioActual() async => _usuarios[_uid];

  @override
  Future<void> crearCuentaCuidador({
    required String nombre,
    required String apellidos,
    required String telefono,
    required String correo,
    required String contrasena,
  }) async {
    final uid = _crearCuenta(
      nombre,
      apellidos,
      correo,
      contrasena,
      Rol.cuidador,
    );
    _telefonos[uid] = telefono;
  }

  String _crearCuenta(
    String nombre,
    String apellidos,
    String correo,
    String contrasena,
    Rol rol,
  ) {
    if (_contrasenas.containsKey(correo)) {
      throw const ErrorNana('Ese correo ya tiene cuenta. Inicia sesión.');
    }
    if (contrasena.length < 6) {
      throw const ErrorNana(
        'La contraseña necesita al menos 6 letras o números.',
      );
    }
    final uid = _nuevoId();
    _contrasenas[correo] = (uid, contrasena);
    _usuarios[uid] = Usuario(
      uid: uid,
      nombre: nombre,
      apellidos: apellidos,
      rol: rol,
    );
    _uid = uid;
    return uid;
  }

  @override
  Future<void> iniciarSesion(String correo, String contrasena) async {
    final cuenta = _contrasenas[correo];
    if (cuenta == null || cuenta.$2 != contrasena) {
      throw const ErrorNana('El correo o la contraseña no coinciden.');
    }
    _uid = cuenta.$1;
  }

  @override
  Future<void> restablecerContrasena(String correo) async {}

  @override
  Future<void> registrarAdulto({
    required String nombre,
    required String apellidos,
    required String correo,
    required String contrasena,
  }) async {
    final uid = _crearCuenta(nombre, apellidos, correo, contrasena, Rol.adulto);
    final folio = _nuevoId();
    _adultos[folio] = Adulto(
      folio: folio,
      nombre: nombre,
      apellidos: apellidos,
      tieneCelular: true,
      uidAdulto: uid,
    );
    _avisar();
  }

  @override
  Future<Adulto> canjearCodigo(String codigo) async {
    final guardado = _codigos[codigo];
    if (guardado == null ||
        guardado.$2 ||
        reloj().isAfter(guardado.$1.expira)) {
      throw const ErrorNana(errorCodigo);
    }
    if (guardado.$1.familiar) throw const ErrorNana(errorCodigoFamiliar);
    final folio = guardado.$1.folio;
    final uid = _uid ?? _nuevoId();
    final adulto = _adultos[folio]!;
    _uid = uid;
    _usuarios[uid] = Usuario(
      uid: uid,
      nombre: adulto.nombre,
      apellidos: adulto.apellidos,
      rol: Rol.adulto,
    );
    _adultos[folio] = Adulto(
      folio: folio,
      nombre: adulto.nombre,
      apellidos: adulto.apellidos,
      tieneCelular: true,
      uidAdulto: uid,
      idsCuidadores: adulto.idsCuidadores,
      telefono: adulto.telefono,
      creadoPor: adulto.creadoPor,
      consentimiento: adulto.consentimiento,
      suplente: adulto.suplente,
      estudio: adulto.estudio,
    );
    _codigos[codigo] = (guardado.$1, true);
    _avisar();
    return _adultos[folio]!;
  }

  @override
  Future<Invitacion> revisarInvitacion(String codigo) async {
    final guardado = _codigos[codigo];
    if (guardado == null ||
        guardado.$2 ||
        reloj().isAfter(guardado.$1.expira)) {
      throw const ErrorNana(errorCodigo);
    }
    if (!guardado.$1.familiar) throw const ErrorNana(errorCodigoDelAdulto);
    return Invitacion(
      codigo: codigo,
      nombreAdulto: _adultos[guardado.$1.folio]?.nombre ?? '',
      nombreInvita: _invita[codigo] ?? '',
    );
  }

  @override
  Future<Adulto> unirmeComoFamiliar(String codigo, String parentesco) async {
    final uid = _uid;
    final guardado = _codigos[codigo];
    if (uid == null ||
        guardado == null ||
        guardado.$2 ||
        reloj().isAfter(guardado.$1.expira)) {
      throw const ErrorNana(errorCodigo);
    }
    if (!guardado.$1.familiar) throw const ErrorNana(errorCodigoDelAdulto);
    final folio = guardado.$1.folio;
    final adulto = _adultos[folio]!;
    if (adulto.idsCuidadores.contains(uid)) {
      throw const ErrorNana(errorYaLaCuidas);
    }
    _adultos[folio] = Adulto(
      folio: folio,
      nombre: adulto.nombre,
      apellidos: adulto.apellidos,
      tieneCelular: adulto.tieneCelular,
      uidAdulto: adulto.uidAdulto,
      idsCuidadores: [...adulto.idsCuidadores, uid],
      telefono: adulto.telefono,
      creadoPor: adulto.creadoPor,
      consentimiento: adulto.consentimiento,
      suplente: adulto.suplente,
      estudio: adulto.estudio,
    );
    _parentescos[(folio, uid)] = parentesco;
    _codigos[codigo] = (guardado.$1, true);
    _avisar();
    return _vistoPor(_adultos[folio]!, uid);
  }

  @override
  Future<void> cerrarSesion() async => _uid = null;

  @override
  Future<String> altaAdulto({
    required String nombre,
    required String apellidos,
    required String parentesco,
    required bool tieneCelular,
    String? telefono,
  }) async {
    final folio = _nuevoId();
    _adultos[folio] = Adulto(
      folio: folio,
      nombre: nombre,
      apellidos: apellidos,
      tieneCelular: tieneCelular,
      idsCuidadores: [_uid!],
      telefono: telefono,
      creadoPor: _uid,
      // Solo se llega aquí después de aceptar la pantalla de permiso.
      consentimiento: reloj(),
    );
    _parentescos[(folio, _uid!)] = parentesco;
    _avisar();
    return folio;
  }

  void _soloPrincipal(String folio) {
    if (_adultos[folio]?.creadoPor != _uid) {
      throw const ErrorNana(errorSinPermiso);
    }
  }

  Adulto _con(
    Adulto a, {
    List<String>? ids,
    Suplente? suplente,
    bool? estudio,
  }) => Adulto(
    folio: a.folio,
    nombre: a.nombre,
    apellidos: a.apellidos,
    tieneCelular: a.tieneCelular,
    uidAdulto: a.uidAdulto,
    idsCuidadores: ids ?? a.idsCuidadores,
    telefono: a.telefono,
    creadoPor: a.creadoPor,
    consentimiento: a.consentimiento,
    suplente: suplente,
    estudio: estudio ?? a.estudio,
  );

  @override
  Future<void> nombrarSuplente(
    String folio,
    String uid, {
    DateTime? hasta,
  }) async {
    _soloPrincipal(folio);
    final a = _adultos[folio]!;
    if (uid == a.creadoPor || !a.idsCuidadores.contains(uid)) {
      throw const ErrorNana('Elige a alguien de la familia de esta persona.');
    }
    if (hasta != null && !hasta.isAfter(reloj())) {
      throw const ErrorNana('Elige una fecha que todavía no pase.');
    }
    _adultos[folio] = _con(
      a,
      suplente: Suplente(uid: uid, hasta: hasta),
    );
    _avisar();
  }

  @override
  Future<void> quitarSuplente(String folio) async {
    _soloPrincipal(folio);
    _adultos[folio] = _con(_adultos[folio]!);
    _avisar();
  }

  @override
  Future<void> quitarFamiliar(String folio, String uid) async {
    _soloPrincipal(folio);
    final a = _adultos[folio]!;
    if (uid == a.creadoPor) {
      throw const ErrorNana('No puedes quitarte: tú diste de alta.');
    }
    _adultos[folio] = _con(
      a,
      ids: [
        for (final id in a.idsCuidadores)
          if (id != uid) id,
      ],
      suplente: a.suplente?.uid == uid ? null : a.suplente,
    );
    _parentescos.remove((folio, uid));
    _avisar();
  }

  @override
  Future<void> dejarDeAcompanar(String folio) async {
    final u = _uid;
    final a = _adultos[folio];
    if (u == null || a == null || !a.idsCuidadores.contains(u)) return;
    if (a.creadoPor == u) throw const ErrorNana(errorPrincipalNoSale);
    _adultos[folio] = _con(
      a,
      ids: [
        for (final id in a.idsCuidadores)
          if (id != u) id,
      ],
      suplente: a.suplente?.uid == u ? null : a.suplente,
    );
    _parentescos.remove((folio, u));
    _avisar();
  }

  @override
  Stream<Apariencia?> apariencia(String folio) =>
      _vigilar(() => _apariencias[folio]);

  @override
  Future<void> guardarApariencia(String folio, Apariencia a) async {
    _soloPrincipal(folio);
    _apariencias[folio] = a.copyWith(actualizado: reloj());
    _avisar();
  }

  // Quién puede abrir "Cómo va la prueba". Las pruebas lo cambian.
  bool adminEstudio = false;
  final uso = <EventoUso>[];

  @override
  Future<void> guardarEstudio(String folio, bool activo) async {
    _soloPrincipal(folio);
    final a = _adultos[folio]!;
    _adultos[folio] = _con(a, suplente: a.suplente, estudio: activo);
    _avisar();
  }

  @override
  Future<void> guardarUso(List<EventoUso> lote, {required String rol}) async =>
      uso.addAll(lote);

  @override
  Future<bool> puedeVerEstudio() async => adminEstudio;

  @override
  Future<List<EventoUso>> usoReciente() async {
    if (!adminEstudio) throw const ErrorNana(errorSinPermiso);
    return List.of(uso);
  }

  @override
  Future<void> borrarAdulto(String folio) async {
    final adulto = _adultos[folio];
    if (adulto == null) return;
    if (adulto.creadoPor != _uid) throw const ErrorNana(errorSoloEncargado);
    _adultos.remove(folio);
    _parentescos.removeWhere((k, _) => k.$1 == folio);
    _codigos.removeWhere((_, v) => v.$1.folio == folio);
    for (final m in <Map<String, Object?>>[
      _medicamentos,
      _registros,
      _alertas,
      _salud,
      _apariencias,
      _reglas,
      _rutinas,
      _recetas,
      _citas,
      _ultima,
    ]) {
      m.remove(folio);
    }
    _avisar();
  }

  @override
  Future<CodigoVinculacion> generarCodigo(
    String folio, {
    bool familiar = false,
  }) async {
    // Invitar es del principal; el código del adulto también lo saca el suplente.
    final a = _adultos[folio];
    final esSuplente =
        a?.suplente?.uid == _uid && (a?.suplente?.vigente(reloj()) ?? false);
    if (a != null && a.creadoPor != _uid && (familiar || !esSuplente)) {
      throw const ErrorNana(errorSinPermiso);
    }
    var codigo = codigoAlAzar(_azar);
    while (_codigos.containsKey(codigo)) {
      codigo = codigoAlAzar(_azar);
    }
    final datos = CodigoVinculacion(
      codigo: codigo,
      folio: folio,
      expira: reloj().add(vigenciaCodigo),
      familiar: familiar,
    );
    _codigos[codigo] = (datos, false);
    if (familiar) _invita[codigo] = _usuarios[_uid]?.nombre ?? '';
    return datos;
  }

  @override
  Stream<bool> codigoUsado(String codigo) =>
      _vigilar(() => _codigos[codigo]?.$2 ?? false);

  Adulto _vistoPor(Adulto a, String? uid) => Adulto(
    folio: a.folio,
    nombre: a.nombre,
    apellidos: a.apellidos,
    tieneCelular: a.tieneCelular,
    uidAdulto: a.uidAdulto,
    idsCuidadores: a.idsCuidadores,
    parentesco: _parentescos[(a.folio, uid)],
    telefono: a.telefono,
    creadoPor: a.creadoPor,
    consentimiento: a.consentimiento,
    suplente: a.suplente,
    estudio: a.estudio,
  );

  @override
  Stream<List<Adulto>> adultosACargo() => _vigilar(
    () => [
      for (final a in _adultos.values)
        if (a.idsCuidadores.contains(_uid)) _vistoPor(a, _uid),
    ],
  );

  @override
  Future<Adulto?> adultoPropio() async {
    for (final a in _adultos.values) {
      if (a.uidAdulto != null && a.uidAdulto == _uid) return a;
    }
    return null;
  }

  @override
  Future<String> nombreDeCuidador(String folio) async {
    final ids = _adultos[folio]?.idsCuidadores ?? const [];
    return ids.isEmpty ? '' : _usuarios[ids.first]?.nombre ?? '';
  }

  @override
  Stream<List<Familiar>> familiaDe(String folio) => _vigilar(
    () => [
      for (final id in _adultos[folio]?.idsCuidadores ?? const <String>[])
        Familiar(
          uid: id,
          nombre: _usuarios[id]?.nombre ?? '',
          telefono: _telefonos[id],
        ),
    ],
  );

  // En memoria el teléfono ya queda guardado al crear la cuenta.
  @override
  Future<void> compartirMiTelefono(String folio) async {}

  @override
  Stream<List<Medicamento>> medicamentos(String folio) => _vigilar(
    () =>
        List.of(_medicamentos[folio] ?? const <Medicamento>[])
          ..sort((a, b) => a.horaTexto.compareTo(b.horaTexto)),
  );

  @override
  Future<void> guardarMedicamento(String folio, Medicamento m) async {
    final lista = _medicamentos.putIfAbsent(folio, () => []);
    if (m.id == null) {
      lista.add(m.conId(_nuevoId()));
    } else {
      // Si ya no está (se borró y se dio "Deshacer"), vuelve a entrar.
      final i = lista.indexWhere((x) => x.id == m.id);
      i == -1 ? lista.add(m) : lista[i] = m;
    }
    _avisar();
  }

  @override
  Future<void> borrarMedicamento(String folio, String id) async {
    _medicamentos[folio]?.removeWhere((m) => m.id == id);
    _avisar();
  }

  @override
  Stream<List<Registro>> registrosDeHoy(String folio) => _vigilar(() {
    final hoy = reloj();
    return [
      for (final r in _registros[folio] ?? const <Registro>[])
        if (DateUtils.isSameDay(r.fecha, hoy)) r,
    ];
  });

  @override
  Future<String> registrar(String folio, Registro r) async {
    final id = r.id ?? _nuevoId();
    _registros
        .putIfAbsent(folio, () => [])
        .add(
          Registro(
            id: id,
            tipo: r.tipo,
            titulo: r.titulo,
            idMedicamento: r.idMedicamento,
            valor: r.valor,
            fecha: r.fecha,
            registradoPor: r.registradoPor,
          ),
        );
    _ultima[folio] = reloj();
    _avisar();
    return id;
  }

  @override
  Future<void> borrarRegistro(String folio, String id) async {
    _registros[folio]?.removeWhere((r) => r.id == id);
    _avisar();
  }

  @override
  Stream<Salud> salud(String folio) =>
      _vigilar(() => _salud[folio] ?? Salud.vacia);

  @override
  Future<void> guardarSalud(String folio, Salud s) async {
    _salud[folio] = s.copyWith(actualizado: reloj());
    _avisar();
  }

  @override
  Stream<List<Alerta>> alertasSinAtender(String folio) => _vigilar(
    () => [
      for (final a in _alertas[folio] ?? const <Alerta>[])
        if (!a.atendida) a,
    ],
  );

  @override
  Future<bool> pedirAyuda(String folio, {String como = 'boton'}) async {
    _alertas
        .putIfAbsent(folio, () => [])
        .add(Alerta(id: _nuevoId(), fecha: reloj(), como: como));
    _avisar();
    return !sinInternet;
  }

  @override
  Future<void> avisarFrase(String folio, String frase) async {
    _alertas
        .putIfAbsent(folio, () => [])
        .add(
          Alerta(id: _nuevoId(), fecha: reloj(), tipo: 'frase', texto: frase),
        );
    _avisar();
  }

  // Tokens de push guardados (para pruebas).
  final List<String> tokensPush = [];

  @override
  Future<void> guardarTokenPush(String token) async {
    if (!tokensPush.contains(token)) tokensPush.add(token);
  }

  @override
  Future<void> atenderAlerta(String folio, String id) async {
    final lista = _alertas[folio] ?? [];
    final i = lista.indexWhere((a) => a.id == id);
    if (i != -1) lista[i] = lista[i].copyWith(atendida: true);
    _avisar();
  }

  @override
  Future<void> responderAlerta(String folio, String id, String estado) async {
    final u = _uid;
    final lista = _alertas[folio] ?? [];
    final i = lista.indexWhere((a) => a.id == id);
    if (u == null || i == -1) return;
    lista[i] = lista[i].copyWith(
      atendida: estado == 'atendi' ? true : null,
      respuestas: {
        ...lista[i].respuestas,
        u: RespuestaAlerta(nombre: _usuarios[u]?.nombre ?? '', estado: estado),
      },
    );
    _avisar();
  }

  @override
  Stream<ReglasAlerta> reglasAlerta(String folio) =>
      _vigilar(() => _reglas[folio] ?? const ReglasAlerta());

  @override
  Future<void> guardarReglasAlerta(String folio, ReglasAlerta r) async {
    _reglas[folio] = r;
    _avisar();
  }

  // Alta o cambio en una lista guardada por folio.
  void _poner<T>(
    Map<String, List<T>> donde,
    String folio,
    T valor,
    String? id,
    String? Function(T) idDe,
    T Function(String) conId,
  ) {
    final lista = donde.putIfAbsent(folio, () => []);
    if (id == null) {
      lista.add(conId(_nuevoId()));
    } else {
      final i = lista.indexWhere((x) => idDe(x) == id);
      i == -1 ? lista.add(valor) : lista[i] = valor;
    }
    _avisar();
  }

  void _quitar<T>(
    Map<String, List<T>> donde,
    String folio,
    String id,
    String? Function(T) idDe,
  ) {
    donde[folio]?.removeWhere((x) => idDe(x) == id);
    _avisar();
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;

  @override
  Stream<List<Rutina>> rutinas(String folio) => _vigilar(
    () =>
        List.of(_rutinas[folio] ?? const <Rutina>[])
          ..sort((a, b) => _min(a.hora).compareTo(_min(b.hora))),
  );

  @override
  Future<void> guardarRutina(String folio, Rutina r) async =>
      _poner(_rutinas, folio, r, r.id, (x) => x.id, r.conId);

  @override
  Future<void> borrarRutina(String folio, String id) async =>
      _quitar(_rutinas, folio, id, (Rutina x) => x.id);

  @override
  Stream<List<Receta>> recetas(String folio) => _vigilar(
    () =>
        List.of(_recetas[folio] ?? const <Receta>[])
          ..sort((a, b) => b.fecha.compareTo(a.fecha)),
  );

  @override
  Future<void> guardarReceta(String folio, Receta r) async =>
      _poner(_recetas, folio, r, r.id, (x) => x.id, r.conId);

  @override
  Future<void> borrarReceta(String folio, String id) async =>
      _quitar(_recetas, folio, id, (Receta x) => x.id);

  @override
  Stream<List<Cita>> citas(String folio) => _vigilar(
    () =>
        List.of(_citas[folio] ?? const <Cita>[])
          ..sort((a, b) => a.fecha.compareTo(b.fecha)),
  );

  @override
  Future<void> guardarCita(String folio, Cita c) async =>
      _poner(_citas, folio, c, c.id, (x) => x.id, c.conId);

  @override
  Future<void> borrarCita(String folio, String id) async =>
      _quitar(_citas, folio, id, (Cita x) => x.id);

  @override
  Stream<List<Registro>> registrosDesde(String folio, DateTime desde) =>
      _vigilar(
        () => [
          for (final r in _registros[folio] ?? const <Registro>[])
            if (!r.fecha.isBefore(desde)) r,
        ]..sort((a, b) => a.fecha.compareTo(b.fecha)),
      );

  @override
  Stream<DateTime?> ultimaActividad(String folio) =>
      _vigilar(() => _ultima[folio]);
}
