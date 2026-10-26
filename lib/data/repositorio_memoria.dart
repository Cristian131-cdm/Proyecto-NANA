import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/codigo.dart';
import '../models/adulto.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/registro.dart';
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
  }

  String? _uid;
  var _siguienteId = 0;
  final _azar = Random(7);
  final _cambios = StreamController<void>.broadcast();

  final _usuarios = <String, Usuario>{};
  final _contrasenas = <String, (String, String)>{}; // correo → (uid, contraseña)
  final _adultos = <String, Adulto>{};
  final _parentescos = <(String, String), String>{}; // (folio, uid) → parentesco
  final _codigos = <String, (CodigoVinculacion, bool)>{}; // código → (datos, usado)
  final _medicamentos = <String, List<Medicamento>>{};
  final _registros = <String, List<Registro>>{};
  final _alertas = <String, List<Alerta>>{};

  String _nuevoId() => 'id${_siguienteId++}';
  void _avisar() => _cambios.add(null);

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
    _crearCuenta(nombre, apellidos, correo, contrasena, Rol.cuidador);
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
    if (guardado == null || guardado.$2 || reloj().isAfter(guardado.$1.expira)) {
      throw const ErrorNana(errorCodigo);
    }
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
    );
    _codigos[codigo] = (guardado.$1, true);
    _avisar();
    return _adultos[folio]!;
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
    );
    _parentescos[(folio, _uid!)] = parentesco;
    _avisar();
    return folio;
  }

  @override
  Future<CodigoVinculacion> generarCodigo(String folio) async {
    var codigo = codigoAlAzar(_azar);
    while (_codigos.containsKey(codigo)) {
      codigo = codigoAlAzar(_azar);
    }
    final datos = CodigoVinculacion(
      codigo: codigo,
      folio: folio,
      expira: reloj().add(vigenciaCodigo),
    );
    _codigos[codigo] = (datos, false);
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
  Stream<List<Medicamento>> medicamentos(String folio) => _vigilar(
    () => List.of(_medicamentos[folio] ?? const <Medicamento>[])
      ..sort((a, b) => a.horaTexto.compareTo(b.horaTexto)),
  );

  @override
  Future<void> guardarMedicamento(String folio, Medicamento m) async {
    final lista = _medicamentos.putIfAbsent(folio, () => []);
    if (m.id == null) {
      lista.add(m.conId(_nuevoId()));
    } else {
      lista[lista.indexWhere((x) => x.id == m.id)] = m;
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
  Future<void> registrar(String folio, Registro r) async {
    _registros.putIfAbsent(folio, () => []).add(r);
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
  Future<bool> pedirAyuda(String folio) async {
    _alertas
        .putIfAbsent(folio, () => [])
        .add(Alerta(id: _nuevoId(), fecha: reloj()));
    _avisar();
    return !sinInternet;
  }

  @override
  Future<void> atenderAlerta(String folio, String id) async {
    final lista = _alertas[folio] ?? [];
    final i = lista.indexWhere((a) => a.id == id);
    if (i != -1) {
      lista[i] = Alerta(id: id, fecha: lista[i].fecha, atendida: true);
    }
    _avisar();
  }
}
