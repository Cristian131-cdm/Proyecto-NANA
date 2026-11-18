import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nana_app/core/ajustes.dart';
import 'package:nana_app/core/biometria.dart';
import 'package:nana_app/core/servicios.dart';
import 'package:nana_app/core/tema.dart';
import 'package:nana_app/data/demo.dart';
import 'package:nana_app/data/repositorio_memoria.dart';
import 'package:nana_app/models/actividad.dart';
import 'package:nana_app/models/adulto.dart';
import 'package:nana_app/screens/alta_adulto.dart';
import 'package:nana_app/screens/bienvenida.dart';
import 'package:nana_app/screens/candado.dart';
import 'package:nana_app/screens/codigo_vinculacion.dart';
import 'package:nana_app/screens/cuenta_cuidador.dart';
import 'package:nana_app/screens/encuesta_apariencia.dart';
import 'package:nana_app/screens/entrar_con_codigo.dart';
import 'package:nana_app/screens/familia_alertas.dart';
import 'package:nana_app/screens/formulario_salud.dart';
import 'package:nana_app/screens/mi_dia.dart';
import 'package:nana_app/screens/mi_familia.dart';
import 'package:nana_app/screens/nana_escucha.dart';
import 'package:nana_app/core/platica.dart';
import 'package:nana_app/screens/platica_nana.dart';
import 'package:nana_app/widgets/ajustes_texto.dart';
import 'package:nana_app/screens/panel_adulto.dart';
import 'package:nana_app/screens/panel_cuidador.dart';
import 'package:nana_app/screens/pantalla_del_adulto.dart';
import 'package:nana_app/screens/pestana_historial.dart';
import 'package:nana_app/screens/pestana_inicio.dart';
import 'package:nana_app/screens/pestana_medicamentos.dart';
import 'package:nana_app/screens/pestana_rutinas.dart';
import 'package:nana_app/screens/pestana_semana.dart';
import 'package:nana_app/screens/pestana_mas.dart';
import 'package:nana_app/screens/mis_ajustes.dart';
import 'package:nana_app/screens/recomendar_huella.dart';
import 'package:nana_app/screens/recordatorio_alarma.dart';
import 'package:nana_app/screens/senas.dart';
import 'package:nana_app/screens/tablero_frases.dart';
import 'package:nana_app/screens/unirme_con_codigo.dart';

// Cada pantalla se abre en celulares chicos y grandes, con la letra normal,
// grande y al tope (Ajustes.escalaMaxima). Si algo no cabe, Flutter lo
// reporta como desborde y la prueba dice en qué combinación pasó.

const _celulares = {
  'Android chico 360x640': Size(360, 640),
  'iPhone 390x844': Size(390, 844),
  'Android grande 412x915': Size(412, 915),
  // Pantalla exterior de un plegable (Z Flip): casi cuadrada.
  'Plegable cerrado 360x390': Size(360, 390),
};
const _letras = [1.0, 1.5, Ajustes.escalaMaxima];

const _losartan = Actividad(
  hora: '8:00',
  titulo: 'Losartán 50 mg',
  detalle: 'Tu medicina',
  tipo: TipoActividad.medicina,
  estado: EstadoActividad.ahora,
  idMedicamento: 'losartan',
);

const _rosa = Adulto(
  folio: 'rosa',
  nombre: 'Rosa',
  apellidos: 'Martínez',
  tieneCelular: true,
  uidAdulto: 'rosa-cel',
  idsCuidadores: ['ana'],
  parentesco: 'mamá',
  telefono: '5500000001',
);

class _SinHuella implements Biometria {
  @override
  Future<bool> disponible() async => false;
  @override
  Future<bool> autenticar(String motivo) async => false;
}

Widget _enHoja(Widget w) => Scaffold(body: SafeArea(child: w));

typedef _Pantalla = ({String sesion, Widget Function() crear});

final _pantallas = <String, _Pantalla>{
  // Entrada y cuentas
  'Bienvenida': (sesion: '', crear: () => const Bienvenida()),
  'Soy cuidador o familiar': (
    sesion: '',
    crear: () => const OpcionesCuidador(),
  ),
  'Crear cuenta': (sesion: '', crear: () => const CuentaCuidador(crear: true)),
  'Iniciar sesión': (
    sesion: '',
    crear: () => const CuentaCuidador(crear: false),
  ),
  'Código de invitación': (sesion: '', crear: () => const InvitadoConCodigo()),
  'Cuenta con invitación': (
    sesion: '',
    crear: () => const CuentaCuidador(
      crear: true,
      invitacion: Invitacion(
        codigo: '482913',
        nombreAdulto: 'María Guadalupe',
        nombreInvita: 'Ana',
      ),
    ),
  ),
  'Entrar con un código': (sesion: '', crear: () => const EntrarConCodigo()),
  'Unirme con código': (sesion: 'ana', crear: () => const UnirmeConCodigo()),
  'Alta del adulto': (sesion: 'ana', crear: () => const AltaAdulto()),
  'Sin celular': (
    sesion: 'ana',
    crear: () => const SinCelular(nombre: 'María Guadalupe'),
  ),
  'Código para el adulto': (
    sesion: 'ana',
    crear: () => PantallaCodigo(
      codigo: CodigoVinculacion(
        codigo: '482913',
        folio: 'rosa',
        expira: DateTime(2026, 11, 13, 9),
      ),
      nombreAdulto: 'María Guadalupe',
    ),
  ),
  'Datos de salud': (
    sesion: 'ana',
    crear: () => const FormularioSalud(folio: 'rosa', nombre: 'Rosa'),
  ),
  'Candado': (sesion: 'ana', crear: () => const Candado()),
  'Recomendar huella': (
    sesion: 'ana',
    crear: () => const RecomendarHuella(destino: SizedBox()),
  ),
  // Persona mayor
  'Encuesta de apariencia': (
    sesion: 'rosa-cel',
    crear: () => const EncuestaApariencia(),
  ),
  'Inicio del adulto': (sesion: 'rosa-cel', crear: () => const PanelAdulto()),
  'Mi día': (
    sesion: 'rosa-cel',
    crear: () => MiDia(folio: 'rosa', onHecha: (_) {}, onAbrir: (_) {}),
  ),
  'Mi familia': (
    sesion: 'rosa-cel',
    crear: () => const MiFamilia(folio: 'rosa'),
  ),
  'Hablar con NANA': (
    sesion: 'rosa-cel',
    crear: () => NanaEscucha(nombre: 'Rosa', onFrase: (_) {}),
  ),
  'Platicando con NANA': (
    sesion: 'rosa-cel',
    crear: () => PlaticaNana(
      saludo: 'Dime, Rosa. Te escucho.',
      responder: (_) async => const RespuestaPlatica('Aquí estoy.'),
      sugerencias: const [
        '¿Qué sigue hoy?',
        'Ya comí',
        'Llama a mi familia',
        '¿Qué hora es?',
      ],
    ),
  ),
  'Ajustar NANA (Aa)': (
    sesion: 'rosa-cel',
    crear: () => Scaffold(body: HojaAjustesAdulto(onCerrarSesion: () {})),
  ),
  'Decir (tablero)': (
    sesion: 'rosa-cel',
    crear: () => TableroFrases(onFrase: (_) {}, onHablar: () {}),
  ),
  'Recordatorio': (
    sesion: 'rosa-cel',
    crear: () => const RecordatorioAlarma(actividad: _losartan, nombre: 'Rosa'),
  ),
  'Ver en señas': (sesion: 'rosa-cel', crear: () => const VerEnSenas()),
  'Permiso de cámara': (
    sesion: 'rosa-cel',
    crear: () => const ConsentimientoCamara(),
  ),
  'Cámara de señas': (sesion: 'rosa-cel', crear: () => const CamaraSenas()),
  // Cuidador
  'Panel del cuidador': (sesion: 'ana', crear: () => const PanelCuidador()),
  'Pestaña Inicio': (
    sesion: 'ana',
    crear: () => _enHoja(const PestanaInicio(adulto: _rosa)),
  ),
  'Pestaña Medicinas': (
    sesion: 'ana',
    crear: () => _enHoja(const PestanaMedicamentos(folio: 'rosa')),
  ),
  'Pestaña Rutinas': (
    sesion: 'ana',
    crear: () => _enHoja(const PestanaRutinas(folio: 'rosa')),
  ),
  'Pestaña Historial': (
    sesion: 'ana',
    crear: () => _enHoja(const PestanaHistorial(adulto: 'Rosa', folio: 'rosa')),
  ),
  'Pestaña Semana': (
    sesion: 'ana',
    crear: () => _enHoja(const PestanaSemana(adulto: 'Rosa', folio: 'rosa')),
  ),
  'Pestaña Más': (
    sesion: 'ana',
    crear: () => _enHoja(const PestanaMas(adulto: _rosa)),
  ),
  'Mis ajustes': (sesion: 'ana', crear: () => const MisAjustes(adulto: _rosa)),
  'Familia y alertas': (
    sesion: 'ana',
    crear: () => const FamiliaAlertas(adulto: 'Rosa', folio: 'rosa'),
  ),
  'Tus datos': (sesion: 'ana', crear: () => const PantallaPrivacidad()),
  'Pantalla del adulto': (
    sesion: 'ana',
    crear: () => const PantallaDelAdulto(adulto: 'Rosa', folio: 'rosa'),
  ),
};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('La letra de NANA por la del celular nunca pasa del tope', () {
    addTearDown(() => Ajustes.escalaTexto.value = 1.0);
    Ajustes.escalaTexto.value = 1.5;
    expect(Ajustes.escalaTotal(2.0), Ajustes.escalaMaxima);
    expect(Ajustes.escalaTotal(1.0), 1.5);
    Ajustes.escalaTexto.value = 1.0;
    expect(Ajustes.escalaTotal(1.3), 1.3);
  });

  for (final MapEntry(key: nombre, value: p) in _pantallas.entries) {
    testWidgets('$nombre cabe con cualquier letra', (t) async {
      addTearDown(t.view.reset);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final fallas = <String>[];
      var combinacion = '';
      // Se anota cada desborde con el archivo y la línea del widget.
      final anterior = FlutterError.onError;
      FlutterError.onError = (d) {
        final donde = RegExp(r'lib/[\w/]+\.dart:\d+')
            .firstMatch(d.toString())
            ?.group(0);
        final que = d.exceptionAsString().split('\n').first;
        fallas.add('$combinacion: $que (${donde ?? 'sin ubicación'})');
      };
      addTearDown(() => FlutterError.onError = anterior);

      for (final MapEntry(key: celular, value: tamano) in _celulares.entries) {
        for (final letra in _letras) {
          SharedPreferences.setMockInitialValues({});
          await Ajustes.cargar();
          Servicios.reloj = () => DateTime(2026, 11, 12, 9);
          final repo = RepositorioMemoria(
            reloj: Servicios.reloj,
            sesion: p.sesion.isEmpty ? null : p.sesion,
          );
          await cargarDemo(repo, 'rosa', Servicios.reloj());
          Servicios.repo = repo;
          Servicios.biometria = _SinHuella();
          debugDefaultTargetPlatformOverride = celular.startsWith('iPhone')
              ? TargetPlatform.iOS
              : TargetPlatform.android;

          combinacion = '$celular, letra x$letra';
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = tamano;
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(
            MaterialApp(
              theme: TemaNana.tema,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(letra)),
                child: child!,
              ),
              home: p.crear(),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 250));
          }
        }
      }
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = anterior;
      expect(fallas, isEmpty, reason: fallas.join('\n'));
    });
  }
}
