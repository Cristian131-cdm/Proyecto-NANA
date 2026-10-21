import '../models/actividad.dart';

// Datos de prueba mientras no hay Firebase. Los dos paneles leen de aquí
// para que lo que ve Rosa y lo que ve su familia coincida.
class DatosEjemplo {
  static const adulto = 'Rosa';
  static const parentesco = 'mamá';

  static const diaRosa = [
    Actividad(
      hora: '7:30',
      titulo: 'Desayuno',
      detalle: 'Listo',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.hecha,
    ),
    Actividad(
      hora: '8:00',
      titulo: 'Losartán 50 mg',
      detalle: 'Una pastilla con agua',
      tipo: TipoActividad.medicina,
      estado: EstadoActividad.ahora,
    ),
    Actividad(
      hora: '2:00 pm',
      titulo: 'Comida',
      detalle: 'Más tarde',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.pendiente,
    ),
    Actividad(
      hora: '6:00 pm',
      titulo: 'Caminar 15 min',
      detalle: 'Más tarde',
      tipo: TipoActividad.ejercicio,
      estado: EstadoActividad.pendiente,
    ),
  ];

  // Lo mismo, visto desde el lado del cuidador.
  static const diaParaCuidador = [
    Actividad(
      hora: '7:30',
      titulo: 'Desayunó',
      detalle: '',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.hecha,
    ),
    Actividad(
      hora: '8:00',
      titulo: 'Losartán sin confirmar',
      detalle: '',
      tipo: TipoActividad.medicina,
      estado: EstadoActividad.sinConfirmar,
    ),
    Actividad(
      hora: '9:10',
      titulo: 'Dijo: "Me siento bien"',
      detalle: '',
      tipo: TipoActividad.animo,
      estado: EstadoActividad.hecha,
    ),
    Actividad(
      hora: '18:00',
      titulo: 'Caminar 15 min',
      detalle: '',
      tipo: TipoActividad.ejercicio,
      estado: EstadoActividad.pendiente,
    ),
  ];

  static const rutinas = [
    Actividad(
      hora: '7:30',
      titulo: 'Desayuno',
      detalle: 'Todos los días',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.pendiente,
    ),
    Actividad(
      hora: '2:00 pm',
      titulo: 'Comida',
      detalle: 'Todos los días',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.pendiente,
    ),
    Actividad(
      hora: '6:00 pm',
      titulo: 'Caminar 15 min',
      detalle: 'Lunes a viernes',
      tipo: TipoActividad.ejercicio,
      estado: EstadoActividad.pendiente,
    ),
    Actividad(
      hora: '8:00 pm',
      titulo: 'Estiramientos',
      detalle: 'Martes y jueves',
      tipo: TipoActividad.ejercicio,
      estado: EstadoActividad.pendiente,
    ),
    Actividad(
      hora: '8:30 pm',
      titulo: 'Cena',
      detalle: 'Todos los días',
      tipo: TipoActividad.comida,
      estado: EstadoActividad.pendiente,
    ),
  ];

  // Números de prueba: solo abren el marcador, no llaman solos.
  static const telefonoAdulto = '5500000001';

  // (nombre, parentesco, rol, teléfono)
  static const familia = [
    ('Ana', 'hija', 'Administradora · recibe todas las alertas', '5500000002'),
    ('Luis', 'hijo', 'Solo ve el resumen', '5500000003'),
    ('Sofía', 'nieta', 'Solo ve el resumen', '5500000004'),
  ];

  // (nombre, relación) de otros adultos que cuida la misma persona
  static const adultosACargo = [
    ('Rosa', 'mamá'),
    ('Ernesto', 'papá'),
  ];

  // Tomas a tiempo por día, de 2 posibles (lunes a domingo)
  static const tomasSemana = [2, 2, 1, 2, 2, 2, 1];

  // Índice de CaritasAnimo: 0 muy bien ... 4 muy mal
  static const animoSemana = [1, 1, 2, 1, 0, 1, 3];

  // (médico, fecha, indicación)
  static const recetas = [
    ('Dr. Pérez', '2 oct', 'Losartán 50 mg · 1 al día'),
    ('Dra. Ruiz', '15 sep', 'Metformina 850 mg · 2 al día'),
  ];

  static const padecimientos = ['Hipertensión', 'Diabetes tipo 2'];
  static const alergias = ['Penicilina'];

  // (especialidad, fecha, lugar)
  static const citas = [
    ('Cardiología', '28 oct · 10:30 am', 'Clínica 25'),
    ('Análisis de sangre', '4 nov · 8:00 am', 'Laboratorio del IMSS'),
  ];
}
