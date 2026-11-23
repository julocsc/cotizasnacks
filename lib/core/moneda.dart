/// Monedas que puede usar una cotización.
///
/// El código [codigo] es el valor ISO 4217 que se guarda en Firestore, mientras
/// que [simbolo] se usa para mostrar los importes en la interfaz y en el PDF.
class Moneda {
  const Moneda({
    required this.codigo,
    required this.nombre,
    required this.simbolo,
    this.decimales = 2,
  });

  final String codigo;
  final String nombre;
  final String simbolo;

  /// Cantidad de decimales que se muestran al formatear importes.
  final int decimales;

  static const Moneda solPeruano = Moneda(
    codigo: 'PEN',
    nombre: 'Sol peruano',
    simbolo: 'S/',
  );
  static const Moneda dolarEstadounidense = Moneda(
    codigo: 'USD',
    nombre: 'Dólar estadounidense',
    simbolo: r'US$',
  );
  static const Moneda euro = Moneda(
    codigo: 'EUR',
    nombre: 'Euro',
    simbolo: '€',
  );
  static const Moneda yenJapones = Moneda(
    codigo: 'JPY',
    nombre: 'Yen japonés',
    simbolo: '¥',
    decimales: 0,
  );
  static const Moneda libraEsterlina = Moneda(
    codigo: 'GBP',
    nombre: 'Libra esterlina',
    simbolo: '£',
  );
  static const Moneda dolarAustraliano = Moneda(
    codigo: 'AUD',
    nombre: 'Dólar australiano',
    simbolo: r'A$',
  );
  static const Moneda dolarCanadiense = Moneda(
    codigo: 'CAD',
    nombre: 'Dólar canadiense',
    simbolo: r'C$',
  );
  static const Moneda yuanChino = Moneda(
    codigo: 'CNY',
    nombre: 'Yuan chino',
    simbolo: 'CN¥',
  );

  /// Monedas disponibles en el selector, en el orden en que se muestran.
  static const List<Moneda> todas = <Moneda>[
    solPeruano,
    dolarEstadounidense,
    euro,
    yenJapones,
    libraEsterlina,
    dolarAustraliano,
    dolarCanadiense,
    yuanChino,
  ];

  /// Moneda usada cuando una cotización no especifica otra.
  static const Moneda predeterminada = solPeruano;

  /// Texto para menús y etiquetas, por ejemplo `PEN · Sol peruano (S/)`.
  String get etiqueta => '$codigo · $nombre ($simbolo)';

  /// Nombre y código, por ejemplo `Sol peruano (PEN)`.
  String get nombreConCodigo => '$nombre ($codigo)';

  /// Busca una moneda por su código ISO.
  ///
  /// Si el código no está entre las monedas soportadas (por ejemplo, una
  /// cotización antigua en MXN) se conserva el código para no perder el dato.
  static Moneda desdeCodigo(String? codigo) {
    final normalizado = (codigo ?? '').trim().toUpperCase();
    if (normalizado.isEmpty) return predeterminada;

    for (final moneda in todas) {
      if (moneda.codigo == normalizado) return moneda;
    }

    return Moneda(
      codigo: normalizado,
      nombre: normalizado,
      simbolo: normalizado,
    );
  }
}
