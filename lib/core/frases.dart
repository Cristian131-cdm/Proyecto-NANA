// Qué significa cada frase rápida del adulto para su familia. Lista fija,
// sin IA: así siempre se comporta igual.

// Estas además le llegan al cuidador como alerta arriba en su Inicio.
const frasesPreocupantes = {
  'Me siento mal',
  'Me duele algo',
  'Me siento triste',
  'Algo me preocupa',
  'Quiero hablar con mi familia',
};

// "Ya desayuné" marca la comida de ese nombre como hecha.
const _comidas = {
  'Ya desayuné': 'Desayuno',
  'Ya comí': 'Comida',
  'Ya cené': 'Cena',
};

// Frases de ánimo → índice de CaritasAnimo (0 muy bien ... 4 muy mal).
const _animos = {
  'Estoy de buenas': 0,
  'Me siento bien': 1,
  'Me siento triste': 3,
  'Me siento mal': 3,
};

String? comidaDeFrase(String frase) => _comidas[frase];

int? animoDeFrase(String frase) => _animos[frase];

bool esPreocupante(String frase) => frasesPreocupantes.contains(frase);
