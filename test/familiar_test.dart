import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/avisos.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/data/repositorio.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/adulto.dart';
import 'package:nana_app/models/alerta.dart';
import 'package:nana_app/screens/alerta_ayuda.dart';
import 'package:nana_app/screens/bienvenida_familiar.dart';
import 'package:nana_app/screens/mis_alertas.dart';
import 'package:nana_app/screens/panel_cuidador.dart';

// La vista del familiar invitado: bienvenida, «pidió ayuda» con «Ya voy»,
// salirse por su cuenta y «Mis alertas» de este celular.

class _AvisosAnotados implements Avisos {
  final titulos = <String>[];
  @override
  Future<void> pedirPermiso() async {}
  @override
  Future<void> mostrar(int id, String titulo, String cuerpo) async =>
      titulos.add(titulo);
}

void main() {
  late RepositorioMemoria repo;
  final ahora = DateTime(2026, 11, 18, 10);
  var momento = ahora;

  // Ana dio de alta a Rosa. Luis entra con una invitación.
  Future<Adulto> entraLuis() async {
    final codigo = await repo.generarCodigo('rosa', familiar: true);
    await repo.crearCuentaCuidador(
      nombre: 'Luis',
      apellidos: '',
      telefono: '5500000003',
      correo: 'luis@gmail.com',
      contrasena: 'secreto1',
    );
    return repo.unirmeComoFamiliar(codigo.codigo, 'abuela');
  }

  Future<void> esperar(WidgetTester t, [int veces = 6]) async {
    for (var i = 0; i < veces; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ajustes.cargar();
    momento = ahora;
    Servicios.reloj = () => momento;
    repo = RepositorioMemoria(reloj: Servicios.reloj);
    Servicios.repo = repo;
  });

  testWidgets('Al unirse ve a quién acompaña, quién lo invitó y qué puede', (
    t,
  ) async {
    final rosa = await entraLuis();
    expect(rosa.creadoPor, 'ana');
    await t.pumpWidget(MaterialApp(home: BienvenidaFamiliar(adulto: rosa)));
    await esperar(t);
    expect(find.text('Ya acompañas a Rosa'), findsOneWidget);
    expect(find.text('Te invitó Ana, que la cuida.'), findsOneWidget);
    expect(find.text('Recibir sus alertas'), findsOneWidget);
    expect(
      find.text(
        'Sus medicinas, rutinas y su expediente solo los cambia Ana.',
      ),
      findsOneWidget,
    );
    await t.scrollUntilVisible(find.text('Empezar'), 200);
    await t.tap(find.text('Empezar'));
    await esperar(t);
    expect(find.byType(PanelCuidador), findsOneWidget);
    expect(find.text('Eres familiar'), findsOneWidget);
  });

  testWidgets('«Ya voy» le dice a la familia quién va; «Ya la atendí» la cierra', (
    t,
  ) async {
    final rosa = await entraLuis();
    await repo.pedirAyuda('rosa');
    final alerta = (await repo.alertasSinAtender('rosa').first).single;

    await t.pumpWidget(
      MaterialApp(home: AlertaAyuda(adulto: rosa, alerta: alerta)),
    );
    await esperar(t);
    expect(find.text('Rosa pidió ayuda'), findsOneWidget);
    expect(find.text('Nadie ha respondido todavía.'), findsOneWidget);

    await t.tap(find.text('Ya voy'));
    await esperar(t);
    expect(find.text('Luis (tú)'), findsOneWidget);
    expect(find.text('Va para allá'), findsOneWidget);
    final respuestas = (await repo.alertasSinAtender('rosa').first)
        .single
        .respuestas;
    expect(respuestas.values.single.estado, 'voy');

    await t.scrollUntilVisible(find.text('Ya la atendí'), -200);
    await t.tap(find.text('Ya la atendí'));
    await esperar(t);
    expect(await repo.alertasSinAtender('rosa').first, isEmpty);
  });

  test('El familiar se sale por su cuenta; el principal no puede', () async {
    await entraLuis();
    expect(await repo.adultosACargo().first, hasLength(1));
    await repo.dejarDeAcompanar('rosa');
    expect(await repo.adultosACargo().first, isEmpty);

    await repo.iniciarSesion('ana@nana.mx', 'secreto1');
    expect(
      () => repo.dejarDeAcompanar('rosa'),
      throwsA(
        isA<ErrorNana>().having(
          (e) => e.mensaje,
          'mensaje',
          errorPrincipalNoSale,
        ),
      ),
    );
    expect((await repo.adultosACargo().first).single.idsCuidadores, ['ana']);
  });

  testWidgets('Mis alertas guarda lo que calla este celular', (t) async {
    await t.pumpWidget(const MaterialApp(home: MisAlertas(adulto: 'Rosa')));
    await esperar(t, 2);
    expect(find.text('Pidió ayuda'), findsOneWidget);
    expect(find.text('Siempre suena. No se puede apagar.'), findsOneWidget);
    await t.tap(find.text('Frases que dice Rosa'));
    await esperar(t, 2);
    expect(Ajustes.callarFrases.value, isTrue);
    expect(Ajustes.callarMedicina.value, isFalse);
  });

  test('Con las frases calladas solo avisa cuando pide ayuda', () async {
    Ajustes.callarFrases.value = true;
    addTearDown(() => Ajustes.callarFrases.value = false);
    final avisos = _AvisosAnotados();
    final vigilante = VigilanteAlertas(
      avisos: avisos,
      nombre: 'Rosa',
      ahora: ahora,
    )..escuchar(repo.alertasSinAtender('rosa'));
    await Future<void>.delayed(Duration.zero);

    momento = ahora.add(const Duration(minutes: 5));
    await repo.avisarFrase('rosa', 'Me duele algo');
    await Future<void>.delayed(Duration.zero);
    await repo.pedirAyuda('rosa');
    await Future<void>.delayed(Duration.zero);
    expect(avisos.titulos, ['Rosa necesita ayuda']);
    vigilante.cancelar();
  });

  test('Las respuestas se leen igual de Firestore', () {
    final r = RespuestaAlerta.deMapa({
      'luis': {'nombre': 'Luis', 'estado': 'voy'},
      'ana': {'nombre': 'Ana', 'estado': 'atendi'},
      'raro': 'no es mapa',
    });
    expect(r.keys, ['luis', 'ana']);
    expect(r['ana']!.atendio, isTrue);
  });
}
